@import Carbon;
@import CoreServices;

#import <signal.h>
#import <util.h>

#import "Settings.h"
#import "Install.h"


// http://stackoverflow.com/questions/13355363/
//    nstask-requires-flush-when-reading-from-a-process-stdout-terminal-does-not
@interface NSTask (PTY)
- (NSFileHandle *)masterSideOfPTYOrError:(NSError **)error;
@end

@implementation NSTask (PTY)
- (NSFileHandle *)masterSideOfPTYOrError:(NSError *__autoreleasing *)error {
  int fdMaster, fdSlave;
  int rc = openpty(&fdMaster, &fdSlave, NULL, NULL, NULL);
  if (rc != 0) {
    if (error) {
      *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
    }
    return NULL;
  }
  fcntl(fdMaster, F_SETFD, FD_CLOEXEC);
  fcntl(fdSlave, F_SETFD, FD_CLOEXEC);
  NSFileHandle *masterHandle = [[NSFileHandle alloc] initWithFileDescriptor:fdMaster
                                                             closeOnDealloc:YES];
  NSFileHandle *slaveHandle = [[NSFileHandle alloc] initWithFileDescriptor:fdSlave
                                                            closeOnDealloc:YES];
  self.standardError = slaveHandle;
  self.standardOutput = slaveHandle;
  return masterHandle;
}
@end

@interface Install ()
@property (weak) IBOutlet NSProgressIndicator *progressBar;
@property Settings *settings;
@property (weak) IBOutlet NSTextField *rebootField;
@property int recoveryPartitionLoopCounter;
@property NSNumber *installPercent;
@property NSFileHandle *masterHandle;
@property NSTask *installer;
@end

@implementation Install

- (void)viewDidLoad {
  [super viewDidLoad];
  struct sigaction action = { 0 };
  action.sa_handler = SIG_IGN;
  sigaction(SIGUSR1, &action, NULL);
  
  self.settings = [[Settings alloc] init];
  self.recoveryPartitionLoopCounter = 1;
  [self.progressBar startAnimation:nil];
  [self performSelectorInBackground:@selector(mountDiskImage) withObject:nil];
}

- (void)mountDiskImage {
  NSArray *hdiutilArgs = @[@"attach", @"-nobrowse", @"-mountpoint", self.settings.kMountPoint,
                           self.settings.kDownloadedFilePath];
  NSTask *hdiutil = [[NSTask alloc] init];
  
  NSPipe *outputPipe = [NSPipe pipe];
  NSPipe *errorPipe = [NSPipe pipe];
  [hdiutil setLaunchPath:@"/usr/bin/hdiutil"];
  [hdiutil setArguments:hdiutilArgs];
  [hdiutil setStandardOutput:outputPipe];
  [hdiutil setStandardError:errorPipe];
  [hdiutil launch];
  [hdiutil waitUntilExit];
  
  if ([hdiutil terminationStatus] != 0) {
    NSData *outputData = [[outputPipe fileHandleForReading] readDataToEndOfFile];
    NSLog(@"%@", [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding]);
    NSData *errorData = [[outputPipe fileHandleForReading] readDataToEndOfFile];
    NSLog(@"%@", [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding]);
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Error mounting disk image. Please contact Support.";
    [alert performSelectorOnMainThread:@selector(runModal) withObject:nil waitUntilDone:NO];
    return;
  }
  [self performSelectorOnMainThread:@selector(installPackage) withObject:nil waitUntilDone:NO];
}

- (void)installPackage {
  self.progressBar.indeterminate = NO;
  
  NSArray *dirContents = [[NSFileManager defaultManager]
      contentsOfDirectoryAtPath:self.settings.kMountPoint
                          error:nil];
  NSPredicate *filter = [NSPredicate predicateWithFormat:@"self ENDSWITH '.app'"];
  NSString *app = [[dirContents filteredArrayUsingPredicate:filter] objectAtIndex:0];
  NSString *appPath = [NSString stringWithFormat:@"%@/%@", self.settings.kMountPoint, app];
  NSString *startosinstallPath = [NSString stringWithFormat:@"%@/%@/%@", self.settings.kMountPoint,
                                  app, self.settings.kStartosinstallPath];

  self.installer = [[NSTask alloc] init];
  self.installer.launchPath = startosinstallPath;
  self.installer.arguments = @[@"--agreetolicense",
                               @"--volume", @"/",
                               @"--applicationpath", appPath,
                               @"--pidtosignal",
                               @([[NSProcessInfo processInfo] processIdentifier]).stringValue,
                               @"--rebootdelay", @"60"];

  NSError *error;
  self.masterHandle = [self.installer masterSideOfPTYOrError:&error];
  if (!self.masterHandle) {
    NSLog(@"Error: could not set up PTY for task: %@", error);
    return;
  }

  // Add observer for output data
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(dataAvailable:)
                                               name:NSFileHandleReadCompletionNotification
                                             object:self.masterHandle];
  [self.installer launch];
  [self.masterHandle readInBackgroundAndNotify];
}

- (void)rebootCountdown:(NSNumber *)secondsRemaining {
  NSString *message = @"Mac will reboot in %ds. Click continue to reboot now.";
  self.rebootField.stringValue = [NSString stringWithFormat:message, secondsRemaining.intValue];
  self.installPercent = @(60 - secondsRemaining.intValue);
  if (secondsRemaining.intValue > 0) {
    [self performSelector:@selector(rebootCountdown:)
               withObject:@(secondsRemaining.intValue - 1)
               afterDelay:1.0];
  }
}

- (void)dataAvailable:(NSNotification *)notification {
  NSData *inData = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
  if (inData && [inData length]) {
    NSString *inText = [[NSString alloc] initWithData:inData encoding:NSUTF8StringEncoding];
    
    for (NSString *incomingLine in [inText componentsSeparatedByString:@"\n"]) {
      // Remove tabs
      NSString *cleanLine = [incomingLine stringByReplacingOccurrencesOfString:@"\t"
                                                                    withString:@" "];
      // Don't process empty lines
      if (cleanLine.length == 0) {
        continue;
      }
      NSLog(@"%@", cleanLine);
      if ([cleanLine hasPrefix:@"Preparing "] && ![cleanLine containsString:@"to run"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
          self.installPercent = @(
              [[cleanLine substringWithRange:NSMakeRange(10, cleanLine.length - 4 - 10)]
               floatValue]);
        });
      } else if ([cleanLine containsString:@"Waiting to reboot for"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
          self.canAdvance = YES;
          self.installPercent = @(0);
          self.progressBar.maxValue = 60.0;
          [self rebootCountdown:@(60)];
        });
        break;
      }
    }
  }
  if (self.installer.isRunning) {
    [self.masterHandle readInBackgroundAndNotify];
  }
}

- (void)stageWillDisappear {
  [super stageWillDisappear];
  if (self.installer.isRunning) {
    NSLog(@"Sending startosinstall SIGUSR1 signal");
    kill(self.installer.processIdentifier, SIGUSR1);
    [self.installer waitUntilExit];
  }
}

@end
