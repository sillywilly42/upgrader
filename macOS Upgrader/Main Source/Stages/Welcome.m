@import QuartzCore;

#import "FonzieView.h"
#import "FonzieWindow.h"
#import "Welcome.h"

@interface Welcome ()
@property (weak) IBOutlet FonzieView *imageView;
@property (strong) IBOutlet NSImageView *osLogo;
@property (strong) IBOutlet NSImageView *fonzie;
@end

@implementation Welcome

- (void)viewDidLoad {
  [super viewDidLoad];
  self.canAdvance = YES;
  
  CATransition *transition = [CATransition animation];
  [transition setType:kCATransitionFade];
  [transition setTimingFunction:
   [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
  [transition setSpeed:0.3333f];
  self.imageView.wantsLayer = YES;
  self.imageView.animations = @{@"subviews": transition};
  
  self.imageView.customViews = @[self.fonzie, self.osLogo];
  [self.imageView addSubview:self.osLogo];
}

-(void)viewDidAppear {
  ((FonzieWindow *)self.view.window).customView = self.imageView;
}
@end
