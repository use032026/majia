

#import "HLPopCommen.h"

UIButton * createActionBtn(NSString *title, SEL action, id Self) {
    UIButton *btn = [[UIButton alloc] init];
    btn.backgroundColor = UIColorMake(255, 255, 255);
    [btn setTitle:title forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:actionBtnFont];
    btn.titleLabel.textAlignment = NSTextAlignmentCenter;
    if ([title isEqualToString:@"确定"]) {
        [btn setTitleColor:SureBtnColor forState:UIControlStateNormal];
        [btn setTitleColor:[SureBtnColor colorWithAlphaComponent:0.25] forState:UIControlStateHighlighted];
    }
    else {
        [btn setTitleColor:NormalBtnColor forState:UIControlStateNormal];
        [btn setTitleColor:[NormalBtnColor colorWithAlphaComponent:0.25] forState:UIControlStateHighlighted];
    }
    [btn addTarget:Self action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

UILabel * createTitle(UIColor *backColor) {
    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.font = [UIFont boldSystemFontOfSize:titleFont];
    titleLbl.textAlignment = NSTextAlignmentCenter;
    titleLbl.textColor = TitleColor;
    titleLbl.backgroundColor = backColor;
    return titleLbl;
}

UILabel * createSubTitle(UIColor *backColor) {
    UILabel *subTitleLbl = [[UILabel alloc] init];
    subTitleLbl.font = [UIFont systemFontOfSize:subTitleFont];
    subTitleLbl.textAlignment = NSTextAlignmentCenter;
    subTitleLbl.textColor = SubTitleColor;
    subTitleLbl.backgroundColor = backColor;
    return subTitleLbl;
}
