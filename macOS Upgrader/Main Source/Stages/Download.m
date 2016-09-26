@import SystemConfiguration;

#include <netinet/in.h>
#include <arpa/inet.h>

#import "DownloadManager.h"
#import "Settings.h"
#import "Download.h"

@interface Download ()
@property (weak) IBOutlet NSButton *pauseButton;
@property (weak) IBOutlet NSProgressIndicator *progressBar;
@property (weak) IBOutlet NSTextField *progressLabel;
@property DownloadManager *downloadManager;
@property float downloadPercentage;
@property Settings *settings;
@end

@implementation Download

- (void)viewDidLoad {
  [super viewDidLoad];
  self.settings = [[Settings alloc] init];
  [self chooseDownloadServer];
}

- (void)chooseDownloadServer {
  NSMutableURLRequest *request =
      [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://internal-network-check"]];
  [request setHTTPMethod:@"HEAD"];
  [request setTimeoutInterval:2.0];
  
  NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                              completionHandler:^(NSData * _Nullable data,
                                                  NSURLResponse * _Nullable response,
                                                  NSError * _Nullable error) {
      if (error) {
        NSLog(@"Corp network not detected.");
        [self startDownloadWithHost:self.settings.kJDSExternalHost];
      } else {
        NSLog(@"Corp network detected.");
        NSString *netblock = [self getNetblock];
        NSLog(@"This host's netblock: %@", netblock);
        
        NSString *chosenJDS = self.settings.kJDSExternalHost;
        NSString *site = [self.settings.kNetblocks objectForKey:netblock];
        if (site) {
          NSString *jds = [self.settings.kJDS objectForKey:site];
          if (jds) {
            chosenJDS = jds;
          }
        }
        NSLog(@"Chosen JDS: %@", chosenJDS);
        [self startDownloadWithHost:chosenJDS];
      }
  }];
  [task resume];
}

- (NSString *)getNetblock {
  SCDynamicStoreRef storeRef = SCDynamicStoreCreate(NULL, (CFStringRef)@"FindCurrentInterfaceIpMac",
                                                    NULL, NULL);
  CFPropertyListRef global = SCDynamicStoreCopyValue (storeRef,CFSTR("State:/Network/Global/IPv4"));
  
  NSString *primaryInterface = [(__bridge NSDictionary *)global valueForKey:@"PrimaryInterface"];
  if (!primaryInterface) {
    CFRelease(storeRef);
    return nil;
  }
  
  NSString *interfaceState = [NSString stringWithFormat:@"State:/Network/Interface/%@/IPv4",
                              primaryInterface];
  
  CFPropertyListRef ipv4 = SCDynamicStoreCopyValue(storeRef, (CFStringRef)interfaceState);
  CFRelease(storeRef);
  
  NSString *ip = [(__bridge NSDictionary *)ipv4 valueForKey:@"Addresses"][0];
  NSString *netmask = [(__bridge NSDictionary *)ipv4 valueForKey:@"SubnetMasks"][0];
  CFRelease(ipv4);
  if (!ip || !netmask) {
    return nil;
  }
 
  struct in_addr ipAddr, mask, network;
  inet_aton([ip cStringUsingEncoding:NSASCIIStringEncoding], &ipAddr);
  inet_aton([netmask cStringUsingEncoding:NSASCIIStringEncoding], &mask);
  network.s_addr = ipAddr.s_addr & mask.s_addr;
  
  // Reformat the address from network byte order to a regular mask.
  uint8_t byte1 = (mask.s_addr >> 0) & 0xFF;
  uint8_t byte2 = (mask.s_addr >> 8) & 0xFF;
  uint8_t byte3 = (mask.s_addr >> 16) & 0xFF;
  uint8_t byte4 = (mask.s_addr >> 24) & 0xFF;
  uint32_t shiftingMask = (byte1 << 24) | (byte2 << 16) | (byte3 << 8) | (byte4 << 0);
  
  int hostBits = 0;
  for (int i = 0; i < 32; i++) {
    if ((shiftingMask & 1) == 0) {
      hostBits++;
      shiftingMask >>= 1;
    } else {
      break;
    }
  }

  return [NSString stringWithFormat:@"%s/%d", inet_ntoa(network), 32 - hostBits];
}

- (void)startDownloadWithHost:(NSString *)host {
  NSString *url = [NSString stringWithFormat:self.settings.kURLPattern, host];
  self.downloadManager = [[DownloadManager alloc] initWithURL:[NSURL URLWithString:url]
                                                     savePath:self.settings.kDownloadedFilePath];
  
  [self.downloadManager addObserver:self
                         forKeyPath:@"bytesWritten"
                            options:NSKeyValueObservingOptionNew
                            context:NULL];
  [self.downloadManager addObserver:self
                         forKeyPath:@"downloadComplete"
                            options:NSKeyValueObservingOptionNew
                            context:NULL];
  [self.downloadManager startDownload];
}

- (IBAction)toggleDownload:(NSButton *)sender {
  if ([sender.title isEqualToString:@"Pause"]) {
    sender.title = @"Resume";
    [self.downloadManager pauseDownload];
  } else if ([sender.title isEqualToString:@"Resume"]) {
    sender.title = @"Pause";
    [self.downloadManager resumeDownload];
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSString *,id> *)change
                       context:(void *)context {
  if ([keyPath isEqualToString:@"bytesWritten"]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      self.downloadPercentage = ((float)self.downloadManager.bytesWritten /
                                 (float)self.downloadManager.totalBytes) * 100.0;
      self.progressLabel.stringValue =
          [NSString stringWithFormat:@"%ldMB of %ldMB", self.downloadManager.bytesWritten / 1048576,
                                                        self.downloadManager.totalBytes / 1048576];
    });
  } else if ([keyPath isEqualToString:@"downloadComplete"]) {
    if (self.downloadManager.downloadComplete) {
      [self.downloadManager removeObserver:self forKeyPath:@"bytesWritten"];
      [self.downloadManager removeObserver:self forKeyPath:@"downloadComplete"];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      self.pauseButton.enabled = !self.downloadManager.downloadComplete;
    });
    self.canAdvance = self.downloadManager.downloadComplete;
    self.shouldAdvance = self.downloadManager.downloadComplete;
  }
}

@end
