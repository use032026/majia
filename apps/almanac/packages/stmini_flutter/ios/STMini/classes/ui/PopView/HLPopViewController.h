

#import <UIKit/UIKit.h>
#import "HLPopView.h"
#import "HLPopConfig.h"

NS_ASSUME_NONNULL_BEGIN


typedef void(^completeBlock)(NSDictionary *info, BOOL isCanel);


typedef void(^isTouchBinBlock)(BOOL isTouchBin);


typedef enum {
    HLPopTargetAnimationScale = 0,
    HLPopTargetAnimationSlider,
} HLPopTargetAnimationMode;


@interface HLPopViewController : UIViewController


- (void)showCenterPopView:(nonnull HLPopView *)popView config:(nullable HLPopConfig *)config complete:(nullable completeBlock)completion;


- (void)showTopPopView:(nonnull HLPopView *)popView config:(nullable HLPopConfig *)config complete:(nullable completeBlock)completion;


- (void)showLeftPopView:(nonnull HLPopView *)popView atTargetView:(nullable UIView *)targetView config:(nullable HLPopConfig *)config complete:(nullable completeBlock)completion;


- (void)showBottomPopView:(nonnull HLPopView *)popView config:(nullable HLPopConfig *)config complete:(nullable completeBlock)completion;


- (void)showRightPopView:(nonnull HLPopView *)popView atTargetView:(nullable UIView *)targetView config:(nullable HLPopConfig *)config complete:(nullable completeBlock)completion;


- (void)showPopView:(nonnull HLPopView *)popView atTargetView:(nonnull UIView *)targetView config:(nullable HLPopConfig *)config  animationMode:(HLPopTargetAnimationMode)animationMode complete:(nullable completeBlock)completion;


- (void)showPopView:(nonnull HLPopView *)popView withTargetFrame:(CGRect)targetFrame config:(nullable HLPopConfig *)config  animationMode:(HLPopTargetAnimationMode)animationMode complete:(nullable completeBlock)completion;


- (void)addBinView:(UIView *)binView isTouchBin:(isTouchBinBlock)block;

@end

NS_ASSUME_NONNULL_END
