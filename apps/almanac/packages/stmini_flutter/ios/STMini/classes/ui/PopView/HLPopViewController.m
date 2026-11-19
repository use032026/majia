

#import "HLPopViewController.h"


static CGFloat usingSpringWithDamping = 0.8;
static CGFloat initialSpringVelocity = 1.1;


static CGFloat blurAlpha = 0.35;


static CGFloat MinTopGap = 80;

static CGFloat MinLeftGap = 0;

static CGFloat MinBottomGap = 80;

static CGFloat MinRightGap = 0;

typedef enum {
    HLPopModeCenter  = 0,
    HLPopModeTop,
    HLPopModeLeft,
    HLPopModeBottom,
    HLPopModeRight,
    HLPopModeDependTarget
} HLPopMode;

@interface HLPopViewController ()<HLPopViewDelegate, UIGestureRecognizerDelegate>


@property (nonatomic, strong) HLPopView *popView;

@property (nonatomic, assign) CGSize originalSize;

@property (nonatomic, strong) UIView *targetView;

@property (nonatomic, strong) UIWindow *containerWindow;

@property (nonatomic, weak) UIWindow *previousWindow;

@property (nonatomic, strong) UIView *blurView;

@property (nonatomic, assign) HLPopMode popMode;

@property (nonatomic, assign) HLPopTargetAnimationMode animateMode;

@property (nonatomic, strong) completeBlock block;

@property (nonatomic, assign) BOOL isDismissing;

@property (nonatomic, strong) HLPopConfig *config;

@property (nonatomic, assign) BOOL isDependFrame;

@property (nonatomic, strong) UIImageView *draggingItemImageView;

@property (nonatomic, strong) UIView *binView;

@property (nonatomic, strong) isTouchBinBlock binBlock;

@end

@implementation HLPopViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    if (self.config.isTapDismiss) {
        UIGestureRecognizer *ges = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(disMiss:)];
        [self.view addGestureRecognizer:ges];
        ges.delegate = self;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.popView popViewWillAppear];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self.popView popViewWillLayoutSubviews];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (!self.isDismissing) {
        self.blurView.frame = self.view.bounds;
        if (self.binView) {
            self.binView.frame = CGRectMake(0, self.view.bounds.size.height - self.binView.frame.size.height, self.binView.frame.size.width, self.binView.frame.size.height);
        }
        if (self.popMode == HLPopModeCenter) {
            CGPoint point = CGPointMake(((self.view.bounds.size.width - self.originalSize.width)/2 + self.config.offset.x) < MinLeftGap ? MinLeftGap : (self.view.bounds.size.width - self.originalSize.width)/2 + self.config.offset.x, ((self.view.bounds.size.height - self.originalSize.height)/2 + self.config.offset.y) < MinTopGap ? MinTopGap : (self.view.bounds.size.height - self.originalSize.height)/2 + self.config.offset.y);
            self.popView.frame = CGRectMake(point.x, point.y, (self.view.frame.size.width - self.originalSize.width - point.x) < MinRightGap ? (self.view.frame.size.width - MinRightGap - point.x) : self.originalSize.width, (self.view.frame.size.height - self.originalSize.height - point.y) < MinBottomGap ? (self.view.frame.size.height - MinBottomGap - point.y) : self.originalSize.height);
        }
        else if (self.popMode == HLPopModeTop) {
            self.popView.frame = CGRectMake((self.view.bounds.size.width - self.originalSize.width)/2 + self.config.offset.x, 0 + self.config.offset.y, self.originalSize.width, self.originalSize.height);
        }
        else if (self.popMode == HLPopModeLeft) {
            if (self.targetView) {
                CGPoint targetPoint = CGPointMake(self.targetView.frame.origin.x + self.targetView.frame.size.width/2 + self.config.targetOffset.x, self.targetView.frame.origin.y + self.targetView.frame.size.height + self.config.targetOffset.y);
                CGPoint currentPoint = [self.view convertPoint:targetPoint fromView:self.targetView.superview];
                self.popView.frame = CGRectMake(currentPoint.x - self.originalSize.width/2 + self.config.offset.x, currentPoint.y + self.config.offset.y, self.originalSize.width, self.originalSize.height);
            }
            else {
                self.popView.frame = CGRectMake(0 + self.config.offset.x, (self.view.bounds.size.height - self.originalSize.height)/2 + self.config.offset.y, self.originalSize.width, self.originalSize.height);
            }
        }
        else if (self.popMode == HLPopModeBottom) {
            self.popView.frame = CGRectMake((self.view.bounds.size.width - self.originalSize.width)/2 + self.config.offset.x, self.view.bounds.size.height - self.originalSize.height + self.config.offset.y, self.originalSize.width, self.originalSize.height);
        }
        else if (self.popMode == HLPopModeRight) {
            if (self.targetView) {
                CGPoint targetPoint = CGPointMake(self.targetView.frame.origin.x + self.targetView.frame.size.width/2 + self.config.targetOffset.x, self.targetView.frame.origin.y + self.targetView.frame.size.height + self.config.targetOffset.y);
                CGPoint currentPoint = [self.view convertPoint:targetPoint fromView:self.targetView.superview];
                self.popView.frame = CGRectMake(currentPoint.x - self.originalSize.width/2 + self.config.offset.x, currentPoint.y + self.config.offset.y, self.originalSize.width, self.originalSize.height);
            }
            else {
                self.popView.frame = CGRectMake(self.view.bounds.size.width - self.originalSize.width + self.config.offset.x, (self.view.bounds.size.height - self.originalSize.height)/2 + self.config.offset.y, self.originalSize.width, self.originalSize.height);
            }
        }
        else if (self.popMode == HLPopModeDependTarget) {
            CGPoint targetPoint = CGPointMake(self.targetView.frame.origin.x + self.targetView.frame.size.width/2 + self.config.targetOffset.x, self.targetView.frame.origin.y + self.targetView.frame.size.height + self.config.targetOffset.y);
            CGPoint currentPoint = [self.view convertPoint:targetPoint fromView:self.targetView.superview];
            self.popView.frame = CGRectMake(currentPoint.x - self.originalSize.width/2 + self.config.offset.x, currentPoint.y + self.config.offset.y, self.originalSize.width, self.originalSize.height);
            if (self.animateMode == HLPopTargetAnimationSlider && self.config.isAlinePopView) {
                self.blurView.frame = CGRectMake(CGRectGetMinX(self.popView.frame), CGRectGetMinY(self.popView.frame), self.popView.frame.size.width, self.blurView.frame.size.height - CGRectGetMinY(self.popView.frame));
            }
        }
        else {
        }
    }
    [self.popView popViewDidLayoutSubviews];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.popView popViewDidAppear];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.popView popViewWillDisappear];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.popView popViewDidDisappear];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - public
#pragma mark 中间弹出窗
- (void)showCenterPopView:(nonnull HLPopView *)popView config:(nullable HLPopConfig *)config complete:(nullable completeBlock)completion {
    [self setWindowWithPopView:popView config:config popMode:HLPopModeCenter complete:completion];
    [self showPopView];
}

#pragma mark 顶部弹出窗
- (void)showTopPopView:(nonnull HLPopView *)popView config:(nullable HLPopConfig *)config complete:(nullable completeBlock)completion {
    [self setWindowWithPopView:popView config:config popMode:HLPopModeTop complete:completion];
    [self showPopView];
}

#pragma mark 左边弹出窗
- (void)showLeftPopView:(nonnull HLPopView *)popView atTargetView:(nullable UIView *)targetView config:(nullable HLPopConfig *)config complete:(nullable completeBlock)completion {
    self.targetView = targetView;
    [self setWindowWithPopView:popView config:config popMode:HLPopModeLeft complete:completion];
    [self showPopView];
}

#pragma mark 底部弹出窗
- (void)showBottomPopView:(nonnull HLPopView *)popView config:(nullable HLPopConfig *)config complete:(nullable completeBlock)completion {
    [self setWindowWithPopView:popView config:config popMode:HLPopModeBottom complete:completion];
    [self showPopView];
}

#pragma mark 右侧弹出窗
- (void)showRightPopView:(nonnull HLPopView *)popView atTargetView:(nullable UIView *)targetView config:(nullable HLPopConfig *)config complete:(nullable completeBlock)completion {
    self.targetView = targetView;
    [self setWindowWithPopView:popView config:config popMode:HLPopModeRight complete:completion];
    [self showPopView];
}

#pragma mark 根据目标视图弹出窗
- (void)showPopView:(nonnull HLPopView *)popView atTargetView:(nonnull UIView *)targetView config:(nullable HLPopConfig *)config animationMode:(HLPopTargetAnimationMode)animationMode complete:(nullable completeBlock)completion {
    self.targetView = targetView;
    self.animateMode = animationMode;
    [self setWindowWithPopView:popView config:config popMode:HLPopModeDependTarget complete:completion];
    [self showPopView];
}

#pragma mark 根据目标frame弹出窗
- (void)showPopView:(nonnull HLPopView *)popView withTargetFrame:(CGRect)targetFrame config:(nullable HLPopConfig *)config  animationMode:(HLPopTargetAnimationMode)animationMode complete:(nullable completeBlock)completion {
    
    UIView *targetView = [[UIView alloc] init];
    targetView.frame = targetFrame;
    targetView.backgroundColor = [UIColor clearColor];
    [[UIApplication sharedApplication].delegate.window addSubview:targetView];
    self.isDependFrame = YES;
    self.targetView = targetView;
    self.animateMode = animationMode;
    [self setWindowWithPopView:popView config:config popMode:HLPopModeDependTarget complete:completion];
    [self showPopView];
}

#pragma mark 添加垃圾箱
- (void)addBinView:(UIView *)binView isTouchBin:(nonnull isTouchBinBlock)block {
    self.binView = binView;
    self.binBlock = block;
}

#pragma mark - 配置弹出窗口
- (void)setWindowWithPopView:(HLPopView *)popView config:(nullable HLPopConfig *)config popMode:(HLPopMode)mode complete:(completeBlock)completion{
    self.originalSize = popView.frame.size;
    self.popView = popView;
    self.config = config == nil ? [[HLPopConfig alloc] init] : config;
    self.popView.config = self.config;
    self.blurView.backgroundColor = self.config.isBackClear ? [UIColor clearColor] : [UIColor blackColor];
    self.popMode = mode;
    self.block = completion;
    popView.delegate = self;
    self.previousWindow = [UIApplication sharedApplication].keyWindow;
    [self.containerWindow makeKeyAndVisible];
}

#pragma mark - UIGestureRecognizerDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    CGPoint touchPoint = [touch locationInView:self.view];
    if (touchPoint.x > CGRectGetMinX(self.popView.frame) && touchPoint.y > CGRectGetMinY(self.popView.frame) && touchPoint.x < CGRectGetMaxX(self.popView.frame) && touchPoint.y < CGRectGetMaxY(self.popView.frame)) {
        return NO;
    }
    return YES;
}

#pragma mark - HLPopViewDelegate
- (void)disMissPopView:(NSDictionary *)info {
    __weak typeof (self) ws = self;
    [self dismissPopViewWithCompleteHandler:^{
        if (nil != ws.block) {
            ws.block(info, NO);
        }
    }];
}

- (void)draggingPopViewItemAtPoint:(CGPoint)point {
    if (self.draggingItemImageView.hidden) {
        
        self.draggingItemImageView.image = [self makeImageWithView:self.popView.draggingItem];
    }
    CGPoint currentPoint = [self.view convertPoint:point fromView:self.popView];
    self.draggingItemImageView.frame = CGRectMake(currentPoint.x - self.popView.draggingItem.frame.size.width/2, currentPoint.y - self.popView.draggingItem.frame.size.height/2, self.popView.draggingItem.frame.size.width, self.popView.draggingItem.frame.size.height);
    
    if (!CGRectContainsRect(self.popView.frame, self.draggingItemImageView.frame)) {
        
        NSLog(@"---移出范围");
        self.draggingItemImageView.hidden = NO;
        
        self.popView.draggingItem.hidden = YES;
        self.popView.isDraggingOut = YES;
        
        if (CGRectIntersectsRect(self.binView.frame, self.draggingItemImageView.frame)) {
            if (self.binBlock) {
                self.binBlock(YES);
            }
        }
        else {
            if (self.binBlock) {
                self.binBlock(NO);
            }
        }
    }
    else {
        NSLog(@"---未移出范围");
        
        self.draggingItemImageView.hidden = YES;
        
        self.popView.draggingItem.hidden = NO;
        self.popView.isDraggingOut = NO;
    }
}

- (void)finishDraggingPopViewItemAndBackToPoint:(CGPoint)originalPoint endBlock:(HLPopViewFinishDraggingBlock)endBlock removeBlock:(HLPopViewDraggingRemoveBlock)removeBlock {
    
    if (CGRectIntersectsRect(self.binView.frame, self.draggingItemImageView.frame)) {
        
        [UIView animateWithDuration:0.3 animations:^{
            self.draggingItemImageView.layer.affineTransform = CGAffineTransformMakeScale(0, 0);
                } completion:^(BOOL finished) {
                    self.draggingItemImageView.hidden = YES;
                    self.draggingItemImageView.layer.affineTransform = CGAffineTransformMakeScale(1.0, 1.0);
                    if (removeBlock) {
                        removeBlock();
                    }
                }];
    }
    else {
        
        if (!self.draggingItemImageView.hidden) {
            CGPoint centerPoint = [self.view convertPoint:originalPoint fromView:self.popView];
            [UIView animateWithDuration:0.4
                             delay:0
            usingSpringWithDamping:usingSpringWithDamping
             initialSpringVelocity:initialSpringVelocity
                           options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                        animations:^{
                self.draggingItemImageView.frame = CGRectMake(centerPoint.x - self.popView.draggingItem.frame.size.width/2, centerPoint.y - self.popView.draggingItem.frame.size.height/2, self.popView.draggingItem.frame.size.width, self.popView.draggingItem.frame.size.height);
            } completion:^(BOOL finished) {
                self.draggingItemImageView.hidden = YES;
                if (endBlock) {
                    endBlock();
                }
            }];
        }
    }
}

- (void)updatePopViewFrame:(CGRect)frame {
    CGRect newFrame = self.popView.frame;
    newFrame.size = frame.size;
    self.originalSize = frame.size;
    [UIView animateWithDuration:0.3 animations:^{
        self.popView.frame = newFrame;
    }];
}

#pragma mark - event
#pragma mark 键盘弹出
- (void)keyboardWillShow:(NSNotification *)noti {
    
    
    CGRect rect = [noti.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    double duration = [noti.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    if (CGRectGetMaxY(self.popView.frame) > (self.view.bounds.size.height - rect.size.height)) {
        CGFloat y = (self.view.bounds.size.height - rect.size.height) - self.popView.frame.size.height;
        CGRect rect = self.popView.frame;
        rect.origin.y = y;
        [UIView animateWithDuration:(duration == 0 ? 0.2 : duration) animations:^{
            self.popView.frame = rect;
        }];
    }
}

#pragma mark 弹出弹窗
- (void)showPopView {
    
    if (self.popMode == HLPopModeCenter) {
        CGPoint point = CGPointMake(((self.view.bounds.size.width - self.originalSize.width)/2 + self.config.offset.x) < MinLeftGap ? MinLeftGap : (self.view.bounds.size.width - self.originalSize.width)/2 + self.config.offset.x, ((self.view.bounds.size.height - self.originalSize.height)/2 + self.config.offset.y) < MinTopGap ? MinTopGap : (self.view.bounds.size.height - self.originalSize.height)/2 + self.config.offset.y);
        self.popView.frame = CGRectMake(point.x, point.y, (self.view.frame.size.width - self.originalSize.width - point.x) < MinRightGap ? (self.view.frame.size.width - MinRightGap - point.x) : self.originalSize.width, (self.view.frame.size.height - self.originalSize.height - point.y) < MinBottomGap ? (self.view.frame.size.height - MinBottomGap - point.y) : self.originalSize.height);
        self.blurView.alpha = 0;
        self.popView.alpha = 1;
        self.popView.layer.affineTransform = CGAffineTransformMakeScale(0.1, 0.1);
        [UIView animateWithDuration:0.4
                         delay:0
        usingSpringWithDamping:usingSpringWithDamping
         initialSpringVelocity:initialSpringVelocity
                       options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                    animations:^{
            self.blurView.alpha = blurAlpha;
            self.popView.layer.affineTransform = CGAffineTransformMakeScale(1, 1);
            if (self.binView) {
                self.binView.frame = CGRectMake(0, self.view.bounds.size.height - self.binView.frame.size.height, self.binView.frame.size.width, self.binView.frame.size.height);
            }
        } completion:^(BOOL finished) {
            if (finished) {
                self.popView.layer.affineTransform = CGAffineTransformIdentity;
            }
        }];
    }
    else if (self.popMode == HLPopModeTop) {
        self.popView.frame = CGRectMake((self.view.bounds.size.width - self.originalSize.width)/2 + self.config.offset.x, -self.originalSize.height, self.originalSize.width, self.originalSize.height);
        self.blurView.alpha = 0;
        [UIView animateWithDuration:0.4
                         delay:0
        usingSpringWithDamping:usingSpringWithDamping
         initialSpringVelocity:initialSpringVelocity
                       options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                    animations:^{
            self.blurView.alpha = blurAlpha;
            self.popView.frame = CGRectMake((self.view.bounds.size.width - self.originalSize.width)/2 + self.config.offset.x, 0 + self.config.offset.y, self.originalSize.width, self.originalSize.height);
            if (self.binView) {
                self.binView.frame = CGRectMake(0, self.view.bounds.size.height - self.binView.frame.size.height, self.binView.frame.size.width, self.binView.frame.size.height);
            }
        } completion:^(BOOL finished) {
            if (finished) {
                self.popView.userInteractionEnabled = YES;
            }
        }];
    }
    else if (self.popMode == HLPopModeLeft) {
        if (self.targetView) {
            
            CGPoint targetPoint = CGPointMake(self.targetView.frame.origin.x + self.targetView.frame.size.width/2 + self.config.targetOffset.x, self.targetView.frame.origin.y + self.targetView.frame.size.height + self.config.targetOffset.y);
            CGPoint currentPoint = [self.view convertPoint:targetPoint fromView:self.targetView.superview];
            self.popView.frame = CGRectMake(-self.view.bounds.size.width, currentPoint.y + self.config.offset.y, self.originalSize.width, self.originalSize.height);
            self.popView.arrowPoint = CGPointMake(self.originalSize.width/2 - self.config.offset.x,  0);
        }
        else {
            
            self.popView.frame = CGRectMake(-self.view.bounds.size.width, (self.view.bounds.size.height - self.originalSize.height)/2 + self.config.offset.y, self.originalSize.width, self.originalSize.height);
        }
        self.blurView.alpha = 0;
        [UIView animateWithDuration:0.5
                         delay:0
        usingSpringWithDamping:0.6
         initialSpringVelocity:0.1
                       options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                    animations:^{
            self.blurView.alpha = blurAlpha;
            if (self.targetView) {
                CGPoint targetPoint = CGPointMake(self.targetView.frame.origin.x + self.targetView.frame.size.width/2 + self.config.targetOffset.x, self.targetView.frame.origin.y + self.targetView.frame.size.height + self.config.targetOffset.y);
                CGPoint currentPoint = [self.view convertPoint:targetPoint fromView:self.targetView.superview];
                self.popView.frame = CGRectMake(currentPoint.x - self.originalSize.width/2 + self.config.offset.x, currentPoint.y + self.config.offset.y, self.originalSize.width, self.originalSize.height);
            }
            else {
                self.popView.frame = CGRectMake(0 + self.config.offset.x, (self.view.bounds.size.height - self.originalSize.height)/2 + self.config.offset.y, self.originalSize.width, self.originalSize.height);
            }
            if (self.binView) {
                self.binView.frame = CGRectMake(0, self.view.bounds.size.height - self.binView.frame.size.height, self.binView.frame.size.width, self.binView.frame.size.height);
            }
        } completion:^(BOOL finished) {
            if (finished) {
                self.popView.userInteractionEnabled = YES;
            }
        }];
    }
    else if (self.popMode == HLPopModeBottom) {
        self.popView.frame = CGRectMake((self.view.bounds.size.width - self.originalSize.width)/2 + self.config.offset.x, self.view.bounds.size.height, self.originalSize.width, self.originalSize.height);
        self.blurView.alpha = 0;
        [UIView animateWithDuration:0.4
                         delay:0
        usingSpringWithDamping:usingSpringWithDamping
         initialSpringVelocity:initialSpringVelocity
                       options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                    animations:^{
            self.blurView.alpha = blurAlpha;
            self.popView.frame = CGRectMake((self.view.bounds.size.width - self.originalSize.width)/2 + self.config.offset.x, self.view.bounds.size.height - self.originalSize.height + self.config.offset.y, self.originalSize.width, self.originalSize.height);
            if (self.binView) {
                self.binView.frame = CGRectMake(0, self.view.bounds.size.height - self.binView.frame.size.height, self.binView.frame.size.width, self.binView.frame.size.height);
            }
        } completion:^(BOOL finished) {
            if (finished) {
                self.popView.userInteractionEnabled = YES;
            }
        }];
    }
    else if (self.popMode == HLPopModeRight) {
        if (self.targetView) {
            
            CGPoint targetPoint = CGPointMake(self.targetView.frame.origin.x + self.targetView.frame.size.width/2 + self.config.targetOffset.x, self.targetView.frame.origin.y + self.targetView.frame.size.height + self.config.targetOffset.y);
            CGPoint currentPoint = [self.view convertPoint:targetPoint fromView:self.targetView.superview];
            self.popView.frame = CGRectMake(self.view.bounds.size.width, currentPoint.y + self.config.offset.y, self.originalSize.width, self.originalSize.height);
            self.popView.arrowPoint = CGPointMake(self.originalSize.width/2 - self.config.offset.x,  0);
        }
        else {
            
            self.popView.frame = CGRectMake(self.view.bounds.size.width, (self.view.bounds.size.height - self.originalSize.height)/2 + self.config.offset.y, self.originalSize.width, self.originalSize.height);
        }
        self.blurView.alpha = 0;
        [UIView animateWithDuration:0.5
                         delay:0
        usingSpringWithDamping:0.6
         initialSpringVelocity:0.1
                       options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                    animations:^{
            self.blurView.alpha = blurAlpha;
            if (self.targetView) {
                CGPoint targetPoint = CGPointMake(self.targetView.frame.origin.x + self.targetView.frame.size.width/2 + self.config.targetOffset.x, self.targetView.frame.origin.y + self.targetView.frame.size.height + self.config.targetOffset.y);
                CGPoint currentPoint = [self.view convertPoint:targetPoint fromView:self.targetView.superview];
                self.popView.frame = CGRectMake(currentPoint.x - self.originalSize.width/2 + self.config.offset.x, currentPoint.y + self.config.offset.y, self.originalSize.width, self.originalSize.height);
            }
            else {
                self.popView.frame = CGRectMake(self.view.bounds.size.width - self.originalSize.width + self.config.offset.x, (self.view.bounds.size.height - self.originalSize.height)/2 + self.config.offset.y, self.originalSize.width, self.originalSize.height);
            }
            if (self.binView) {
                self.binView.frame = CGRectMake(0, self.view.bounds.size.height - self.binView.frame.size.height, self.binView.frame.size.width, self.binView.frame.size.height);
            }
        } completion:^(BOOL finished) {
            if (finished) {
                self.popView.userInteractionEnabled = YES;
            }
        }];
    }
    else if (self.popMode == HLPopModeDependTarget) {
        CGPoint targetPoint = CGPointMake(self.targetView.frame.origin.x + self.targetView.frame.size.width/2 + self.config.targetOffset.x, self.targetView.frame.origin.y + self.targetView.frame.size.height + self.config.targetOffset.y);
        CGPoint currentPoint = [self.view convertPoint:targetPoint fromView:self.targetView.superview];
        self.popView.frame = CGRectMake(currentPoint.x - self.originalSize.width/2 + self.config.offset.x, currentPoint.y + self.config.offset.y, self.originalSize.width, self.originalSize.height);
        self.popView.arrowPoint = CGPointMake(self.originalSize.width,  0);
        self.blurView.alpha = 0;
        self.popView.alpha = 1;
        self.popView.layer.affineTransform = self.animateMode == HLPopTargetAnimationScale ? CGAffineTransformMakeScale(0.1, 0.1) : CGAffineTransformMakeScale(1, 0.1);
        self.popView.layer.anchorPoint = self.animateMode == HLPopTargetAnimationScale ? CGPointMake((currentPoint.x + self.config.offset.x)/self.view.bounds.size.width, (currentPoint.y + self.config.offset.y)/self.view.bounds.size.height) : CGPointMake((currentPoint.x + self.config.offset.x)/self.view.bounds.size.width, 0);
        if (self.animateMode == HLPopTargetAnimationSlider && self.config.isAlinePopView) {
            self.blurView.frame = CGRectMake(CGRectGetMinX(self.popView.frame), CGRectGetMinY(self.popView.frame), self.popView.frame.size.width, self.blurView.frame.size.height - CGRectGetMinY(self.popView.frame));
        }
        [UIView animateWithDuration:0.4
                         delay:0
        usingSpringWithDamping:usingSpringWithDamping
         initialSpringVelocity:initialSpringVelocity
                       options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                    animations:^{
            self.blurView.alpha = blurAlpha;
            self.popView.layer.affineTransform = CGAffineTransformMakeScale(1, 1);
            if (self.binView) {
                self.binView.frame = CGRectMake(0, self.view.bounds.size.height - self.binView.frame.size.height, self.binView.frame.size.width, self.binView.frame.size.height);
            }
        } completion:^(BOOL finished) {
            if (finished) {
                self.popView.layer.affineTransform = CGAffineTransformIdentity;
                self.popView.userInteractionEnabled = YES;
            }
        }];
    }
    else {
    }
    [self.view addSubview:self.blurView];
    if (self.binView) {
        [self.view addSubview:self.binView];
    }
    [self.view addSubview:self.popView];
    
    if (self.popView.draggingItem) {
        self.draggingItemImageView = [[UIImageView alloc] init];
        self.draggingItemImageView.hidden = YES;
        [self.view addSubview:self.draggingItemImageView];
    }
}

#pragma mark 弹窗消失
- (void)dismissPopViewWithCompleteHandler:(void(^)(void))completeHandler {
    if (self.config.isHolding) {
        
        return;
    }
    if (self.isDependFrame) {
        
        [self.targetView removeFromSuperview];
        self.isDependFrame = NO;
    }
    [self.popView.layer removeAllAnimations];
    self.isDismissing = YES;
    if (self.popMode == HLPopModeCenter) {
        [UIView animateWithDuration:0.2
                              delay:0
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            self.blurView.alpha = 0;
            self.popView.layer.affineTransform = CGAffineTransformMakeScale(0.7, 0.7);
            self.popView.alpha = 0;
            if (self.binView) {
                self.binView.frame = CGRectMake(0, self.view.bounds.size.height, self.binView.frame.size.width, self.binView.frame.size.height);
            }
        } completion:^(BOOL finished) {
            self.popView.layer.affineTransform = CGAffineTransformIdentity;
            [self reSetWindow];
            if (self.binView) self.binView = nil;
            if (completeHandler) completeHandler();
        }];
    }
    else if (self.popMode == HLPopModeTop) {
        [UIView animateWithDuration:0.5
                         delay:0
        usingSpringWithDamping:usingSpringWithDamping
         initialSpringVelocity:initialSpringVelocity
                       options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                    animations:^{
            self.blurView.alpha = 0;
            self.popView.frame = CGRectMake((self.view.bounds.size.width - self.originalSize.width)/2 + self.config.offset.x, -self.view.bounds.size.height, self.originalSize.width, self.originalSize.height);
            if (self.binView) {
                self.binView.frame = CGRectMake(0, self.view.bounds.size.height, self.binView.frame.size.width, self.binView.frame.size.height);
            }
        } completion:^(BOOL finished) {
            [self reSetWindow];
            if (self.binView) self.binView = nil;
            if (completeHandler) completeHandler();
        }];
    }
    else if (self.popMode == HLPopModeLeft) {
        [UIView animateWithDuration:0.5
                         delay:0
        usingSpringWithDamping:usingSpringWithDamping
         initialSpringVelocity:initialSpringVelocity
                       options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                    animations:^{
            self.blurView.alpha = 0;
            if (self.targetView) {
                
                CGPoint targetPoint = CGPointMake(self.targetView.frame.origin.x + self.targetView.frame.size.width/2 + self.config.targetOffset.x, self.targetView.frame.origin.y + self.targetView.frame.size.height + self.config.targetOffset.y);
                CGPoint currentPoint = [self.view convertPoint:targetPoint fromView:self.targetView.superview];
                self.popView.frame = CGRectMake(-self.view.bounds.size.width, currentPoint.y + self.config.offset.y, self.originalSize.width, self.originalSize.height);
            }
            else {
                
                self.popView.frame = CGRectMake(-self.view.bounds.size.width, (self.view.bounds.size.height - self.originalSize.height)/2 + self.config.offset.y, self.originalSize.width, self.originalSize.height);
            }
            if (self.binView) {
                self.binView.frame = CGRectMake(0, self.view.bounds.size.height, self.binView.frame.size.width, self.binView.frame.size.height);
            }
        } completion:^(BOOL finished) {
            [self reSetWindow];
            if (self.binView) self.binView = nil;
            if (completeHandler) completeHandler();
        }];
    }
    else if (self.popMode == HLPopModeBottom) {
        [UIView animateWithDuration:0.5
                         delay:0
        usingSpringWithDamping:usingSpringWithDamping
         initialSpringVelocity:initialSpringVelocity
                       options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                    animations:^{
            self.blurView.alpha = 0;
            self.popView.frame = CGRectMake((self.view.bounds.size.width - self.originalSize.width)/2 + self.config.offset.x, self.view.bounds.size.height, self.originalSize.width, self.originalSize.height);
            if (self.binView) {
                self.binView.frame = CGRectMake(0, self.view.bounds.size.height, self.binView.frame.size.width, self.binView.frame.size.height);
            }
        } completion:^(BOOL finished) {
            [self reSetWindow];
            if (self.binView) self.binView = nil;
            if (completeHandler) completeHandler();
        }];
    }
    else if (self.popMode == HLPopModeRight) {
        [UIView animateWithDuration:0.5
                         delay:0
        usingSpringWithDamping:usingSpringWithDamping
         initialSpringVelocity:initialSpringVelocity
                       options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                    animations:^{
            self.blurView.alpha = 0;
            if (self.targetView) {
                
                CGPoint targetPoint = CGPointMake(self.targetView.frame.origin.x + self.targetView.frame.size.width/2 + self.config.targetOffset.x, self.targetView.frame.origin.y + self.targetView.frame.size.height + self.config.targetOffset.y);
                CGPoint currentPoint = [self.view convertPoint:targetPoint fromView:self.targetView.superview];
                self.popView.frame = CGRectMake(self.view.bounds.size.width, currentPoint.y + self.config.offset.y, self.originalSize.width, self.originalSize.height);
            }
            else {
                
                self.popView.frame = CGRectMake(self.view.bounds.size.width, (self.view.bounds.size.height - self.originalSize.height)/2 + self.config.offset.y, self.originalSize.width, self.originalSize.height);
            }
            if (self.binView) {
                self.binView.frame = CGRectMake(0, self.view.bounds.size.height, self.binView.frame.size.width, self.binView.frame.size.height);
            }
        } completion:^(BOOL finished) {
            [self reSetWindow];
            if (self.binView) self.binView = nil;
            if (completeHandler) completeHandler();
        }];
    }
    else if (self.popMode == HLPopModeDependTarget) {
        [UIView animateWithDuration:0.2
                              delay:0
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            self.blurView.alpha = 0;
            self.popView.layer.affineTransform = self.animateMode == HLPopTargetAnimationScale ? CGAffineTransformMakeScale(0.7, 0.7) : CGAffineTransformMakeScale(1, 0.1);
            self.popView.alpha = 0;
            if (self.binView) {
                self.binView.frame = CGRectMake(0, self.view.bounds.size.height, self.binView.frame.size.width, self.binView.frame.size.height);
            }
        } completion:^(BOOL finished) {
            self.popView.layer.affineTransform = CGAffineTransformIdentity;
            [self reSetWindow];
            if (self.binView) self.binView = nil;
            
            if (completeHandler) completeHandler();
        }];
    }
    else {
    }
}

- (void)disMiss:(UITapGestureRecognizer *)ges {
    __weak typeof(self) ws = self;
    [self dismissPopViewWithCompleteHandler:^{
        if (ges != nil) {
            if (nil != ws.block) {
                ws.block(@{}, YES);
            }
        }
    }];
}

#pragma mark 重置窗口
- (void)reSetWindow {
    self.containerWindow.hidden = YES;
    self.containerWindow.rootViewController = nil;
    [self.previousWindow makeKeyAndVisible];
    self.isDismissing = NO;
}

#pragma mark - view转图片
- (UIImage *)makeImageWithView:(UIView *)view{
    CGSize size = view.bounds.size;
    UIImage *image;
    if (@available(iOS 10, *)) {
        UIGraphicsImageRendererFormat *format = [[UIGraphicsImageRendererFormat alloc] init];
        format.prefersExtendedRange = YES;
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
        image = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
            return [view.layer renderInContext:rendererContext.CGContext];
        }];
    }
    else {
        UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
        [view.layer renderInContext:UIGraphicsGetCurrentContext()];
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return image;
}

#pragma mark - getter
- (UIWindow *)containerWindow {
    if (!_containerWindow) {
        if (@available(iOS 13.0, *)) {
            
            UIWindowScene *activeScene = [self findActiveWindowScene];
            _containerWindow = [[UIWindow alloc] initWithWindowScene:activeScene];
        } else {
            _containerWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        }
        _containerWindow.windowLevel = UIWindowLevelAlert + 1;
        _containerWindow.rootViewController = self;
        _containerWindow.backgroundColor = [UIColor clearColor];
    }
    return _containerWindow;
}


- (UIWindowScene *)findActiveWindowScene API_AVAILABLE(ios(13.0)) {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive &&
            [scene isKindOfClass:[UIWindowScene class]]) {
            return (UIWindowScene *)scene;
        }
    }
    return nil;
}

- (UIView *)blurView {
    if (!_blurView) {
        _blurView = [[UIView alloc] init];
        _blurView.backgroundColor = [UIColor blackColor];
    }
    return _blurView;
}

@end
