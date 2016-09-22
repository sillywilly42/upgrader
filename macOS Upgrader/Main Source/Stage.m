#import "Stage.h"

@interface Stage ()
@end

@implementation Stage

- (instancetype)init {
  self = [super initWithNibName:[self className] bundle:nil];
  if (self) {
    _canAdvance = NO;
    _shouldAdvance = NO;
  }
  return self;
}

- (void)stageWillDisappear {
}

@end
