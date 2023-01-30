//
//  QUIHighLightLabel.m
//  PureCore
//
//  Created by zcx on 2022/2/22.
//

#import "QUIHighLightLabel.h"

#define LabelMaxLineNumber 1000

#define DefaultLinkColor [UIColor colorWithRed:45.0 / 255 green:119.0 / 255 blue:229.0 / 255 alpha:1]

#pragma mark - HyperLinkTextModel
/// 超链接文本的model
@interface HighLightTextModel : NSObject
/// 超链接文本在全文中的位置
@property (nonatomic, assign) NSRange clickRange;
/// 超链接的颜色，若不设置，默认为蓝色
@property (nonatomic, strong, nullable) UIColor *linkColor;
/// 超链接文本点击态的颜色，默认为蓝色
@property (nonatomic, strong, nullable) UIColor *clickColor;
/// 点击超链接的响应，需要业务方实现并传入
@property (nonatomic, strong) HighLightLabelClickLinkBlock clickBlock;
/// 超链接正处于高亮态（如正被点击），默认值是NO
@property (nonatomic, assign) BOOL isHighLightState;

@end

@implementation HighLightTextModel

- (instancetype)init {
    if (self = [super init]) {
        self.linkColor = DefaultLinkColor;
        self.clickColor = self.linkColor;
    }
    return self;
}

@end

#pragma mark - QUIHighLightLabel

@interface QUIHighLightLabel ()
/// 超链接部分文案被点击时的model，超链接字符串在被点击时和普通状态设置不同的model来实现点击态
/// clickingOriginLinkModel表示touchbegan时被点击的超链接（若被点击的文本非超链接，值为nil）
@property (nonatomic, weak) HighLightTextModel *clickingOriginLinkModel;
/// 本Label文本中所有的超链接
@property (nonatomic, strong) NSMutableArray<HighLightTextModel *> *highLightTexts;

@property (nonatomic, strong) NSArray *accessibleElements;

@end

@implementation QUIHighLightLabel

- (instancetype)init {
    if (self = [super init]) {
        [self initProperties];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self initProperties];
    }
    return self;
}

- (void)initProperties {
    self.highLightTexts = [[NSMutableArray alloc] init];
    self.userInteractionEnabled = YES;

    self.isAccessibilityElement = NO;
}

- (void)addHighLightText:(NSString *)highLightText
               linkColor:(UIColor *)linkColor
              clickColor:(UIColor *)clickColor
              clickBlock:(HighLightLabelClickLinkBlock _Nullable)clickBlock {
    if (highLightText.length == 0) {
        return;
    }

    // 遍历全文，找出文中所有的hyperLinkText并设为超链接
    NSRange searchRange = NSMakeRange(0, self.text.length);
    while (searchRange.location < self.text.length) {
        searchRange.length = self.text.length - searchRange.location;
        NSRange foundRange = [self.text rangeOfString:highLightText options:NSLiteralSearch range:searchRange];
        if (foundRange.location != NSNotFound) {
            [self addHighLightRange:foundRange linkColor:linkColor clickColor:clickColor clickBlock:clickBlock];
            searchRange.location = foundRange.location + foundRange.length;
        } else {
            break;
        }
    }
}

- (void)addHighLightRange:(NSRange)highLightRange
                linkColor:(UIColor *)linkColor
               clickColor:(UIColor *)clickColor
               clickBlock:(HighLightLabelClickLinkBlock _Nullable)clickBlock {
    HighLightTextModel *model = [[HighLightTextModel alloc] init];
    model.linkColor = linkColor ?: DefaultLinkColor;
    model.clickColor = clickColor ?: DefaultLinkColor;
    model.clickBlock = clickBlock;
    model.clickRange = highLightRange;
    [self.highLightTexts addObject:model];

    [self refreshAttributedText];
}

- (void)clearHighLightTexts {
    [self.highLightTexts removeAllObjects];
    // 将全文置为默认颜色
    [self setTextColor:self.textColor ofRange:NSMakeRange(0, self.text.length)];
}

#pragma mark - 绘制视图

- (void)refreshAttributedText {
    NSMutableAttributedString *attributedStr = [self.attributedText mutableCopy];
    for (int i = 0; i < self.highLightTexts.count; ++i) {
        HighLightTextModel *textModel = [self.highLightTexts objectAtIndex:i];
        if (!textModel) {
            continue;
        }

        [attributedStr addAttribute:NSForegroundColorAttributeName value:textModel.linkColor range:textModel.clickRange];
    }
    self.attributedText = [attributedStr copy];
    self.accessibilityElements = nil;
}

- (void)drawClickingText:(HighLightTextModel *)clickingModel {
    if (!clickingModel) {
        // 被点击的位置非超链接
        // 将超链接颜色恢复为非点击态颜色
        [self refreshAttributedText];
    }

    UIColor *clickingTextColor = clickingModel.isHighLightState ? clickingModel.clickColor : clickingModel.linkColor;
    [self setTextColor:clickingTextColor ofRange:clickingModel.clickRange];
}

- (void)resetToNormalState {
    self.clickingOriginLinkModel = nil;
    [self refreshAttributedText];
}

- (void)setTextColor:(UIColor *)color ofRange:(NSRange)range {
    NSMutableAttributedString *attrStr = [self.attributedText mutableCopy];
    [attrStr addAttribute:NSForegroundColorAttributeName value:color range:range];
    self.attributedText = [attrStr copy];
}

#pragma mark - 绘制视图过程中的逻辑计算
/// 返回当前手指停留的超链接的model
- (HighLightTextModel *)highLightModelIsTouching:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    NSUInteger clickCharacterIdx = [self charIndexIsTouching:touches];
    if (clickCharacterIdx < self.attributedText.length) {
        NSArray *models = self.highLightTexts;
        for (int i = 0; i < models.count; ++i) {
            HighLightTextModel *model = [models objectAtIndex:i];
            NSRange range = model.clickRange;
            if (clickCharacterIdx >= range.location && clickCharacterIdx < range.location + range.length) {
                return model;
            }
        }
    }
    return nil;
}

/// 根据手指停留位置获取处于文本的第几个字符
- (NSInteger)characterIndexAtPoint:(CGPoint)location {
    NSTextContainer *textContainer = [self createTextContainer];
    NSLayoutManager *layoutManager = [self createLayoutManagerWithTextContainer:textContainer];
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedText];
    NSRange textRange = NSMakeRange(0, attributedText.length);
    NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
    paragraphStyle.alignment = self.textAlignment;
    [attributedText addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:textRange];
    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:attributedText];
    [textStorage addLayoutManager:layoutManager];
    NSUInteger characterIndex = [layoutManager characterIndexForPoint:location inTextContainer:textContainer
                             fractionOfDistanceBetweenInsertionPoints:NULL];
    return characterIndex;
}

- (NSInteger)charIndexIsTouching:(NSSet<UITouch *> *)touches {
    CGPoint location = [[touches anyObject] locationInView:self];
    if (location.x > CGRectGetWidth(self.frame) || location.x < 0 || location.y < 0 || location.y > CGRectGetHeight(self.frame)) {
        return NSNotFound;
    }

    NSInteger clickCharacterIdx = [self characterIndexAtPoint:location];

    return clickCharacterIdx;
}

- (CGRect)highLightRectOfRange:(NSRange)range {
    //传回layoutManager的位置 实际就是字符串的fram
    NSTextContainer *textContainer = [self createTextContainer];
    NSLayoutManager *layoutManager = [self createLayoutManagerWithTextContainer:textContainer];
    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:self.attributedText];
    [textStorage addLayoutManager:layoutManager];

    NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:range actualCharacterRange:nil];

    return [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:textContainer];
}

- (NSTextContainer *)createTextContainer {
    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:CGSizeMake(CGRectGetWidth(self.bounds), CGFLOAT_MAX)];
    textContainer.maximumNumberOfLines = LabelMaxLineNumber;
    textContainer.lineBreakMode = self.lineBreakMode;
    textContainer.lineFragmentPadding = 0.0;

    return textContainer;
}

- (NSLayoutManager *)createLayoutManagerWithTextContainer:(NSTextContainer *)textContainer {
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    [layoutManager addTextContainer:textContainer];

    return layoutManager;
}

#pragma mark - Accessibility

- (NSInteger)accessibilityElementCount {
    return self.accessibleElements.count;
}

- (id)accessibilityElementAtIndex:(NSInteger)index {
    return [self.accessibleElements objectAtIndex:index];
}

- (NSInteger)indexOfAccessibilityElement:(id)element {
    NSInteger idx = [self.accessibleElements indexOfObject:element];
    return idx;
}

/// 更新所有element的accessibilityFrame
- (void)refreshAccessibilityFrameOfElements {
    for (int i = 0; i < self.accessibleElements.count; ++i) {
        UIAccessibilityElement *element = self.accessibleElements[i];
        [self refreshAccessibilityFrameOfElement:element index:i];
    }
}

- (void)refreshAccessibilityFrameOfElement:(UIAccessibilityElement *)element index:(NSInteger)idx {
    if (idx < 0 || idx > self.highLightTexts.count) {
        // 属于异常情况，不更改element的frame
        return;
    }

    if (idx < self.highLightTexts.count) {
        // 高亮文本的accessibilityFrame为其在Label中的frame
        HighLightTextModel *linkModel = (HighLightTextModel *)self.highLightTexts[idx];
        NSRange range = linkModel.clickRange;
        if (range.location + range.length <= 0 || range.location + range.length > self.text.length) {
            return;
        }
        CGRect rect = [self highLightRectOfRange:range];
        element.accessibilityFrame = [self convertRect:rect toView:self.window];
    } else {
        // 富文本全文的accessibilityFrame为Label的frame
        // 此元素在创建时放在accessibilityElements数组的最后一位
        CGRect rect = self.bounds;
        element.accessibilityFrame = [self convertRect:rect toView:self.window];
    }
}

#pragma mark - TouchDelegate
//代理方法
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.clickingOriginLinkModel = [self highLightModelIsTouching:touches withEvent:event];
    if (!self.clickingOriginLinkModel) {
        // 点击的位置非超链接，不重绘label
        return;
    }
    self.clickingOriginLinkModel.isHighLightState = YES;
    [self drawClickingText:self.clickingOriginLinkModel];
}

/// 当label所在的页面添加了手势，点击label会以touchesEnded结束
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self touchesFinished:touches withEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.clickingOriginLinkModel) {
        // 点击的位置非超链接，不做任何处理
        return;
    }
    // 由于touchesMoved函数被调用的频率很高，因此需要避免在此函数中执行不必要的操作，以免造成性能问题
    // 通过判断currentTouchingModel与clickingOriginLinkModel.isHighLightState来判断是否需要重新绘制
    // 情况分为四种：
    // （1）手指在目标超链接范围内移动，不需要重绘，此时目标超链接为高亮态
    // （2）手指从其他区域移动回到目标超链接范围，需要重绘成高亮态
    // （3）手指从目标超链接范围移动到其他区域，需要重绘成默认链接颜色
    // （4）手指在其他区域移动，不需要重绘，此时目标超链接为默认链接颜色
    HighLightTextModel *currentTouchingModel = [self highLightModelIsTouching:touches withEvent:event];
    // 当前触摸区域位于首次点击的链接文本
    if ([currentTouchingModel isEqual:self.clickingOriginLinkModel]) {
        // 情况（1）手指尚未移出首次点击的链接文本范围，不必重绘，直接返回
        if (self.clickingOriginLinkModel.isHighLightState) {
            return;
        }
        // 情况（2）手指移出首次点击的链接文本后，又移动回来了，需要重新绘制文字颜色
        self.clickingOriginLinkModel.isHighLightState = YES;
        [self drawClickingText:self.clickingOriginLinkModel];
        return;
    }
    // 当前触摸区域位于首次点击的链接文本之外
    if (self.clickingOriginLinkModel.isHighLightState) {
        // 情况（3）触摸点刚刚离开首次被点击的区域，需要重新绘制文字颜色
        self.clickingOriginLinkModel.isHighLightState = NO;
        [self drawClickingText:self.clickingOriginLinkModel];
        return;
    }
    // 情况（4）其余情况是触摸点不在首次点击的链接文本范围内移动，不做任何处理
}

/// 当label所在的页面添加了手势，点击label会以touchesCancelled结束
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self touchesFinished:touches withEvent:event];
}

- (void)touchesFinished:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    NSInteger charIndexTouching = [self charIndexIsTouching:touches];
    // 若手指离开屏幕时的位置在label之外，将label恢复为默认状态
    if (charIndexTouching >= self.attributedText.length) {
        [self resetToNormalState];
        return;
    }

    HighLightTextModel *clickingModel = [self highLightModelIsTouching:touches withEvent:event];
    if (clickingModel.isHighLightState) {
        if (self.clickingOriginLinkModel.clickBlock) {
            self.clickingOriginLinkModel.clickBlock();
        }
    } else {  // 若点击的位置非超链接，执行点击普通文本的回调
        if (self.clickNormalBlock) {
            self.clickNormalBlock();
        }
    }

    [self resetToNormalState];
}

#pragma mark - setter

- (void)setText:(NSString *)text {
    [super setText:text];
    [self clearHighLightTexts];
}

#pragma mark - getter

- (NSArray *)accessibleElements {
    if (!_accessibleElements) {
        NSMutableArray *accessibleElements = [NSMutableArray array];
        for (int i = 0; i < self.highLightTexts.count; ++i) {
            HighLightTextModel *linkModel = (HighLightTextModel *)self.highLightTexts[i];
            NSRange range = linkModel.clickRange;
            if (range.location == NSNotFound || range.location + range.length > self.text.length) {
                continue;
            }
            CGRect rect = [self highLightRectOfRange:range];
            UIAccessibilityElement *element = [[UIAccessibilityElement alloc] initWithAccessibilityContainer:self];
            element.accessibilityLabel = [self.text substringWithRange:range];
            element.accessibilityFrame = [self convertRect:rect toView:self.window];
            element.accessibilityTraits = UIAccessibilityTraitLink;
            [accessibleElements addObject:element];
        }
        CGRect rect = self.bounds;
        UIAccessibilityElement *element = [[UIAccessibilityElement alloc] initWithAccessibilityContainer:self];
        element.accessibilityLabel = self.accessibilityLabel;
        element.accessibilityFrame = [self convertRect:rect toView:self.window];
        element.accessibilityTraits = UIAccessibilityTraitNone;
        [accessibleElements addObject:element];

        _accessibleElements = [accessibleElements copy];
    }
    return _accessibleElements;
}

@end
