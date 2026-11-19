

#import <UIKit/UIKit.h>
#import "HLPopCommen.h"
#import "HLPopConfig.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^HLPopViewFinishDraggingBlock)(void);
typedef void(^HLPopViewDraggingRemoveBlock)(void);


@protocol HLPopViewDelegate <NSObject>


- (void)disMissPopView:(nullable NSDictionary *)info;


- (void)draggingPopViewItemAtPoint:(CGPoint)point;


- (void)finishDraggingPopViewItemAndBackToPoint:(CGPoint)originalPoint endBlock:(HLPopViewFinishDraggingBlock)endBlock removeBlock:(HLPopViewDraggingRemoveBlock)removeBlock;


- (void)updatePopViewFrame:(CGRect)frame;

@end


@interface HLPopView : UIView

@property (nonatomic, weak) id<HLPopViewDelegate> delegate;

@property (nonatomic, assign) CGPoint arrowPoint;

@property (nonatomic, assign) BOOL isNeedArrow;

@property (nonatomic, strong) UIView *contentMaskView;

@property (nonatomic, strong) HLPopConfig *config;

@property (nonatomic, strong) UIView *draggingItem;

@property (nonatomic, assign) BOOL isDraggingOut;


- (void)popViewWillAppear;


- (void)popViewWillLayoutSubviews;


- (void)popViewDidLayoutSubviews;


- (void)popViewDidAppear;


- (void)popViewWillDisappear;


- (void)popViewDidDisappear;

@end

NS_ASSUME_NONNULL_END
