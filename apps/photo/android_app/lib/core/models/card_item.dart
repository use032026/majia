import 'package:freezed_annotation/freezed_annotation.dart';

part 'card_item.freezed.dart';
part 'card_item.g.dart';

/// 卡片数据模型
/// 对齐 iOS `ConfigCardItemData`
@freezed
class CardItem with _$CardItem {
  const factory CardItem({
    required String cardId,
    required String cardStyle,
    required bool isShow,
    String? title,
    String? bgColor,
    String? cardType,      // native / web / mini
    String? link,
    double? aspectRatio,
    Map<String, dynamic>? cardDetail,
    @Default([]) List<String> showPermission,
  }) = _CardItem;

  factory CardItem.fromJson(Map<String, dynamic> json) => _$CardItemFromJson(json);
}