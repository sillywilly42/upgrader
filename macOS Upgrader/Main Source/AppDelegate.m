#import "StageManager.h"

#import "AppDelegate.h"

@interface AppDelegate ()
@property StageManager *stageManager;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  NSDictionary *systemVersion = [NSDictionary
      dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
  if ([systemVersion[@"ProductVersion"] containsString:@"10.12"]) {
    [NSApp terminate:self];
  }
  
  self.stageManager = [[StageManager alloc] initWithWindowNibName:@"StageManager"];
  [self.stageManager showWindow:self];
}

@end
