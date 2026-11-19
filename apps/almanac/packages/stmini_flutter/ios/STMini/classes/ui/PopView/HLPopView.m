

#import "HLPopView.h"

@implementation HLPopView

- (void)popViewWillAppear {}
- (void)popViewWillLayoutSubviews {}
- (void)popViewDidLayoutSubviews {}
- (void)popViewDidAppear {}
- (void)popViewWillDisappear {}
- (void)popViewDidDisappear {}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        [self addSubview:self.contentMaskView];
    }
    return self;
}

- (UIView *)contentMaskView {
    if (!_contentMaskView) {
        _contentMaskView = [[UIView alloc] init];
        _contentMaskView.layer.masksToBounds = YES;
        _contentMaskView.clipsToBounds = YES;
    }
    return _contentMaskView;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.isNeedArrow) {
        return;
    }
    
    self.contentMaskView.backgroundColor = self.config.popBackColor;
    self.contentMaskView.frame = self.bounds;
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds byRoundingCorners:self.config.corner cornerRadii:CGSizeMake(self.config.cornerRadius, self.config.cornerRadius)];
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.frame = self.bounds;
    maskLayer.path = maskPath.CGPath;
    self.contentMaskView.layer.mask = maskLayer;
    
    if (self.config.shadowMode == HLShadowModeNone) {
        
        return;
    }
    if (self.config.shadowMode == HLShadowModeTop || self.config.shadowMode == HLShadowModeAll) {
        
        CALayer *shadowLayer = [[CALayer alloc] init];
        UIBezierPath *path = [UIBezierPath bezierPath];
        shadowLayer.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height*0.5);
        [path moveToPoint:CGPointMake(self.bounds.size.width*0.5, self.bounds.size.height*0.5)];
        [path addLineToPoint:(CGPointMake(0, 0))];
        [path addLineToPoint:(CGPointMake(self.bounds.size.width, 0))];
        shadowLayer.shadowPath = path.CGPath;
        [self handleShadowLayer:shadowLayer];
    }
    if (self.config.shadowMode == HLShadowModeLeft || self.config.shadowMode == HLShadowModeAll) {
        
        CALayer *shadowLayer = [[CALayer alloc] init];
        UIBezierPath *path = [UIBezierPath bezierPath];
        shadowLayer.frame = CGRectMake(0, 0, self.frame.size.height*0.5, self.frame.size.height);
        [path moveToPoint:CGPointMake(self.bounds.size.width*0.5, self.bounds.size.height*0.5)];
        [path addLineToPoint:(CGPointMake(0, 0))];
        [path addLineToPoint:(CGPointMake(0, self.bounds.size.height))];
        shadowLayer.shadowPath = path.CGPath;
        [self handleShadowLayer:shadowLayer];
    }
    if (self.config.shadowMode == HLShadowModeBottom || self.config.shadowMode == HLShadowModeAll) {
        
        CALayer *shadowLayer = [[CALayer alloc] init];
        UIBezierPath *path = [UIBezierPath bezierPath];
        shadowLayer.frame = CGRectMake(0, self.frame.size.height*0.5, self.frame.size.width, self.frame.size.height*0.5);
        [path moveToPoint:CGPointMake(self.bounds.size.width*0.5, 0)];
        [path addLineToPoint:(CGPointMake(0, self.bounds.size.height*0.5))];
        [path addLineToPoint:(CGPointMake(self.bounds.size.width, self.bounds.size.height*0.5))];
        shadowLayer.shadowPath = path.CGPath;
        [self handleShadowLayer:shadowLayer];
    }
    if (self.config.shadowMode == HLShadowModeRight || self.config.shadowMode == HLShadowModeAll) {
        
        CALayer *shadowLayer = [[CALayer alloc] init];
        UIBezierPath *path = [UIBezierPath bezierPath];
        shadowLayer.frame = CGRectMake(self.frame.size.width*0.5, 0, self.frame.size.width*0.5, self.frame.size.height);
        [path moveToPoint:CGPointMake(0, self.bounds.size.height*0.5)];
        [path addLineToPoint:(CGPointMake(self.frame.size.width*0.5, 0))];
        [path addLineToPoint:(CGPointMake(self.frame.size.width*0.5, self.bounds.size.height))];
        shadowLayer.shadowPath = path.CGPath;
        [self handleShadowLayer:shadowLayer];
    }
}

- (void)handleShadowLayer:(CALayer *)shadowLayer {
    shadowLayer.masksToBounds = NO;
    shadowLayer.shadowColor = [UIColor lightGrayColor].CGColor;
    shadowLayer.shadowOpacity = 1;
    shadowLayer.shadowRadius = self.config.cornerRadius;
    shadowLayer.shadowOffset = CGSizeMake(0, 0);
    [self.layer insertSublayer:shadowLayer atIndex:0];
}

-(void)drawRect:(CGRect)rect
{
    if (self.isNeedArrow) {
        
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:self.arrowPoint];
        [path addLineToPoint:CGPointMake(self.arrowPoint.x - arrowWidth, self.arrowPoint.y + arrowHeight)];
        [path addLineToPoint:CGPointMake(self.config.cornerRadius, self.arrowPoint.y + arrowHeight)];
        [path addArcWithCenter:CGPointMake(self.config.cornerRadius, self.arrowPoint.y + arrowHeight + self.config.cornerRadius) radius:self.config.cornerRadius startAngle:-M_PI/2 endAngle:-M_PI clockwise:NO];
        [path addLineToPoint:CGPointMake(0, self.frame.size.height - self.config.cornerRadius)];
        [path addArcWithCenter:CGPointMake(self.config.cornerRadius, self.frame.size.height - self.config.cornerRadius) radius:self.config.cornerRadius startAngle:-M_PI endAngle:-M_PI*3/2 clockwise:NO];
        [path addLineToPoint:CGPointMake(self.frame.size.width - self.config.cornerRadius, self.frame.size.height)];
        [path addArcWithCenter:CGPointMake(self.frame.size.width - self.config.cornerRadius, self.frame.size.height - self.config.cornerRadius) radius:self.config.cornerRadius startAngle:-M_PI*3/2 endAngle:-M_PI*2 clockwise:NO];
        [path addLineToPoint:CGPointMake(self.frame.size.width, self.arrowPoint.y + arrowHeight + self.config.cornerRadius)];
        [path addArcWithCenter:CGPointMake(self.frame.size.width - self.config.cornerRadius, self.arrowPoint.y + arrowHeight + self.config.cornerRadius) radius:self.config.cornerRadius startAngle:0 endAngle:-M_PI/2 clockwise:NO];
        [path addLineToPoint:CGPointMake(self.arrowPoint.x + arrowWidth, self.arrowPoint.y + arrowHeight)];
        [path addLineToPoint:self.arrowPoint];

        path.lineWidth = 1;
        [self.config.popBackColor setFill];
        [self.config.popBackColor setStroke];
        [path stroke];
        [path fill];
        [path closePath];
    }
}

@end
