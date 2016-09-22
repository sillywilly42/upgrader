#import "FonzieWindow.h"

@interface FonzieWindow ()
@property int clickCount;
@end

@implementation FonzieWindow
- (instancetype)init {
  self = [super init];
  if (self) {
    _clickCount = 0;
  }
  return self;
}

- (void)sendEvent:(NSEvent *)theEvent {
  if ([theEvent type] == NSLeftMouseDown && [self.customView hitTest:[theEvent locationInWindow]]) {
    self.clickCount++;
    if (self.clickCount >= 3) [self.customView toggleViews];
  }
  [super sendEvent:theEvent];
}
@end
