/// Banner 轮播条目模型
/// 对齐 iOS: BannerItemModel.initWithDic
///
/// 字段来源:
///   cardDetail[@"items"][]
///   每个 item: { picture, router, link, title, routerModel }
///
/// 路由参数由使用方通过 CardFactory.extractItemRoute 解析
class BannerItemModel {
  final String picture;
  final String title;
  final Map<String, dynamic> raw; // 原始数据，用于路由提取

  const BannerItemModel({
    this.picture = '',
    this.title = '',
    Map<String, dynamic>? raw,
  }) : raw = raw ?? const {};

  factory BannerItemModel.fromJson(Map<String, dynamic> json) {
    return BannerItemModel(
      picture: (json['picture'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      raw: json,
    );
  }
}
