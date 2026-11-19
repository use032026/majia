

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


static const CGFloat arrowHeight = 7;

static const CGFloat arrowWidth = 6;

static const CGFloat radius = 1;

static const CGFloat titleFont = 16;

static const CGFloat subTitleFont = 13;

static const CGFloat cellTitleFont = 15;

static const CGFloat cellsubTitleFont = 13;

static const CGFloat actionBtnFont = 17;

static const CGFloat contentFont = 15;

static const CGFloat titleHeight = 48;

static const CGFloat cellHeight = 48;

static const CGFloat actionBtnHeight = 46;


#define TitleColor UIColorMake(53, 60, 70)

#define SubTitleColor UIColorMake(161, 166, 163)

#define TitleBackColor UIColorMake(255, 255, 255)

#define TitleBackDarkColor UIColorMake(244, 245, 247)

#define CellTitleColor UIColorMake(100, 105, 110)

#define CellTitleDarkColor UIColorMake(53, 60, 70)

#define CellTitleSelColor UIColorMake(49, 189, 243)

#define CellsubTitleColor UIColorMake(161, 166, 163)

#define SeparatorColor UIColorMake(222, 224, 226)

#define SureBtnColor UIColorMake(180, 43, 55)

#define NormalBtnColor UIColorMake(49, 189, 243)

#define UIColorMake(r, g, b) [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1]


extern UIButton * createActionBtn(NSString *title, SEL action, id Self);


extern UILabel * createTitle(UIColor *backColor);


extern UILabel * createSubTitle(UIColor *backColor);
