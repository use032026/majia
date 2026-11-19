

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN


typedef enum {
    HLShadowModeTop = 0,
    HLShadowModeLeft,
    HLShadowModeBottom,
    HLShadowModeRight,
    HLShadowModeAll, 
    HLShadowModeNone 
} HLShadowMode;


typedef enum {
    HLPopDirectionTop = 0,
    HLPopDirectionLeft,
    HLPopDirectionBottom,
    HLPopDirectionRight,
} HLPopDirection;


@interface HLPopConfig : NSObject


@property (nonatomic, assign) BOOL isTapDismiss;

@property (nonatomic, assign) BOOL isBackClear;

@property (nonatomic, assign) UIRectCorner corner;

@property (nonatomic, assign) HLShadowMode shadowMode;

@property (nonatomic, assign) CGFloat cornerRadius;

@property (nonatomic, assign) CGPoint offset;

@property (nonatomic, assign) BOOL isAlinePopView;

@property (nonatomic, strong) UIColor *popBackColor;

@property (nonatomic, assign) BOOL isHolding;

@property (nonatomic, assign) HLPopDirection direction;

@property (nonatomic, assign) CGPoint targetOffset;

@end

NS_ASSUME_NONNULL_END
