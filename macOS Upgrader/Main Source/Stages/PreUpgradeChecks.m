#import "PreUpgradeChecks.h"

@interface PreUpgradeChecks ()
@property (weak) IBOutlet NSTextField *messageField;
@property NSString *errorMessage;
@end

@implementation PreUpgradeChecks

- (void)viewDidLoad {
  [super viewDidLoad];
  self.errorMessage = @"✗ It's not possible to upgrade at this time. Please contact IT Support for assistance.";
  [self doAllChecks:nil];
}

- (IBAction)doAllChecks:(NSButton *)sender {
  BOOL success = [self checkTestFileExists];  // && [self checkSomethingElse] etc...
  if (success) {
    self.messageField.textColor = [NSColor darkGrayColor];
    self.messageField.stringValue = @"✓ All checks have passed! Click continue to move on to the next stage.";
    self.canAdvance = YES;
    self.shouldAdvance = YES;
  } else {
    self.messageField.textColor = [NSColor redColor];
    self.messageField.stringValue = self.errorMessage;
  }
}

-(BOOL)checkTestFileExists {
  self.errorMessage = @"✗ This check is used to simulate what failure looks like.";
  return ![[NSFileManager defaultManager] fileExistsAtPath:@"/tmp/fake-failed-check"];
}

@end
