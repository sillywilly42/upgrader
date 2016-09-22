#import <Cocoa/Cocoa.h>

@interface Stage : NSViewController
@property BOOL canAdvance;
@property BOOL shouldAdvance;

- (void)stageWillDisappear;
@end
