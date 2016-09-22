#import "Settings.h"

NSString * const kPrefsPath = @"/Library/Preferences/com.megacorp.macOS-Upgrader.plist";

@implementation Settings
- (instancetype)init
{
  self = [super init];
  if (self) {
    NSString *path = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    if ([paths count]) {
      NSString *bundleName = [[NSBundle mainBundle] infoDictionary][@"CFBundleIdentifier"];
      path = [paths[0] stringByAppendingPathComponent:bundleName];
    }
    if (path){
      if ([[NSFileManager defaultManager] createDirectoryAtPath:path
                                    withIntermediateDirectories:YES
                                                     attributes:nil
                                                          error:nil]) {
        path = [path stringByAppendingPathComponent:@"InstallOSX.dmg"];
        _kDownloadedFilePath = [NSURL fileURLWithPath:path];
       } else {
        _kDownloadedFilePath = [NSURL URLWithString:@"file:///Users/Shared/InstallOSX.dmg"];
      }
    } else {
      _kDownloadedFilePath = [NSURL URLWithString:@"file:///Users/Shared/InstallOSX.dmg"];
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:kPrefsPath]) {
      NSDictionary *savedSettings = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
      _kJDSExternalHost = savedSettings[@"kJDSExternalHost"];
      _kURLPattern = savedSettings[@"kURLPattern"];
      _kStartosinstallPath = savedSettings[@"kStartosinstallPath"];
      _kMountPoint = savedSettings[@"kMountPoint"];
      _kNetblocks = savedSettings[@"kNetblocks"];
      _kJDS = savedSettings[@"kJDS"];
      
    } else {
    
      _kJDSExternalHost = @"fileserver.external.megacorp.com";
      _kURLPattern = @"https://%@/CasperShare/InstallOSX_10.12_16A323.dmg";
      _kStartosinstallPath = @"Contents/Resources/startosinstall";
      _kMountPoint = @"/Volumes/OSXUpgradeImage";
      
      _kNetblocks = @{
          @"10.0.1.0/24": @"LON",
          @"10.0.2.0/24": @"MTV",
          @"10.0.3.0/24": @"NYC",
      };
      
      _kJDS = @{
          @"LON": @"fileserver.london.megacorp.com",
          @"MTV": @"fileserver.mountainview.megacorp.com",
          @"NYC": @"fileserver.newyork.megacorp.com",
      };
    }
  }
  return self;
}
@end
