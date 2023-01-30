//
//  QUIHighLightLabel.h
//  PureCore
//
//  Created by zcx on 2022/2/22.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^HighLightLabelClickLinkBlock)(void);
typedef void (^HighLightLabelClickNormalBlock)(void);

@interface QUIHighLightLabel : UILabel

/// 当用户点击普通文本时的响应
@property (nonatomic, strong) HighLightLabelClickNormalBlock clickNormalBlock;

/// ‼️调用此方法前，应首先对label.text赋值
/// 调用方需要将要添加超链接的文本以及点击文本的响应都写入HighLightLabel
/// @highLightText 超链接文本，应当为全文本的一部分。若该字符串出现多次，都会被染色成超链接.
/// @linkColor 超链接文本的默认颜色
/// @clickColor 超链接文本的点击态颜色
/// @clickBlock 点击超链接文本的响应函数
- (void)addHighLightText:(NSString *)highLightText
               linkColor:(UIColor *_Nullable)linkColor
              clickColor:(UIColor *_Nullable)clickColor
              clickBlock:(HighLightLabelClickLinkBlock _Nullable)clickBlock;

/// ‼️调用此方法前，应首先对label.text赋值
/// 调用方需要将要添加超链接的文本范围以及点击文本的响应都写入HyperLinkLabel
/// @linkRange 超链接字符串的范围，应当为全文本的一部分。
/// @linkColor 超链接文本的默认颜色
/// @clickColor 超链接文本的点击态颜色
/// @clickBlock 点击超链接文本的响应函数
- (void)addHighLightRange:(NSRange)linkRange
                linkColor:(UIColor *_Nullable)linkColor
               clickColor:(UIColor *_Nullable)clickColor
               clickBlock:(HighLightLabelClickLinkBlock _Nullable)clickBlock;

/// 清空已有的超链接文本设置
/// ‼️如果更改label.text，那么应该先调用此方法，并重新调用addHighLightRange或addHighLightText方法。
- (void)clearHighLightTexts;

/// 由于Label的位置可能会变化，因此也要更新element的accessibilityFrame
- (void)refreshAccessibilityFrameOfElements;

@end

NS_ASSUME_NONNULL_END
