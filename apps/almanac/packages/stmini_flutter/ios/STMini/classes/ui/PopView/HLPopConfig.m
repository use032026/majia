

#import "HLPopConfig.h"

@implementation HLPopConfig

- (instancetype)init {
    if (self = [super init]) {
        self.isTapDismiss = YES;
        self.isBackClear = NO;
        self.corner = UIRectCornerAllCorners;
        self.shadowMode = HLShadowModeNone;
        self.cornerRadius = 8;
        self.offset = CGPointZero;
        self.isAlinePopView = YES;
        self.popBackColor = [UIColor whiteColor];
        self.isHolding = NO;
        self.direction = HLPopDirectionBottom;
    }
    return self;
}

@end
