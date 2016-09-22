@import QuartzCore;

#import "Download.h"
#import "Install.h"
#import "PreUpgradeChecks.h"
#import "Stage.h"
#import "Welcome.h"
#import "FonzieView.h"
#import "FonzieWindow.h"

#import "StageManager.h"

@interface StageManager ()
@property (weak) IBOutlet NSView *stageView;
@property NSArray *stages;
@property int currentStage;
@property Stage *currentStageInstance;
@property CATransition *transition;
@end

@implementation StageManager

- (void)windowDidLoad {
  [super windowDidLoad];
  self.stages = @[
      [Welcome class],
      [PreUpgradeChecks class],
      [Download class],
      [Install class],
  ];
  
  self.currentStage = 0;
  self.currentStageInstance = [[self.stages[self.currentStage] alloc] init];
  [self.stageView addSubview:self.currentStageInstance.view];
  
  [self configureTransition];
  [self.currentStageInstance addObserver:self forKeyPath:@"shouldAdvance" options:0 context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSString *,id> *)change
                       context:(void *)context {
  [self nextStage:nil];
}


- (IBAction)nextStage:(NSButton *)sender {
  [self.currentStageInstance removeObserver:self forKeyPath:@"shouldAdvance"];
  [((Stage *)[self.stageView.subviews[0] nextResponder]) stageWillDisappear];
  
  self.currentStage += 1;
  if (self.currentStage > self.stages.count - 1) {
    [NSApp terminate:self];
  }
  self.currentStageInstance = [[self.stages[self.currentStage] alloc] init];
  [self.currentStageInstance addObserver:self forKeyPath:@"shouldAdvance" options:0 context:NULL];
  self.transition.subtype = kCATransitionFromRight;
  [[self.stageView animator] replaceSubview:self.stageView.subviews[0]
                                       with:self.currentStageInstance.view];
}

- (void)configureTransition {
  self.transition = [CATransition animation];
  [self.transition setType:kCATransitionPush];
  [self.transition setTimingFunction:
   [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
  [self.transition setSpeed:0.3333f];
  [self.stageView setWantsLayer:YES];
  [self.stageView setAnimations:@{ @"subviews": self.transition }];
}
@end
