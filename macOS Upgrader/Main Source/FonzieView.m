#import "FonzieView.h"

@implementation FonzieView
- (void)toggleViews {
  for (NSImageView *imageView in self.customViews) {
    if (![imageView isEqualTo:self.subviews[0]]) {
      [[self animator] replaceSubview:self.subviews[0] with:imageView];
      return;
    }
  }
}
@end
