/// 新闻资讯条目模型
/// 对齐 iOS: NewsListModel.initWithDic
///
/// 字段来源:
///   requestNewsListWithParams:@{@"limit":@4}
///   → response[@"data"][@"list"][]
///   每个 item: { id, title, sub_title, summary, pic_url, picture, publish_time }
class NewsItemModel {
  final int id;
  final String title;
  final String subTitle;
  final String summary;
  final String picUrl;
  final int publishTime; // Unix timestamp (seconds)

  const NewsItemModel({
    this.id = 0,
    this.title = '',
    this.subTitle = '',
    this.summary = '',
    this.picUrl = '',
    this.publishTime = 0,
  });

  factory NewsItemModel.fromJson(Map<String, dynamic> json) {
    return NewsItemModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?) ?? '',
      subTitle: (json['sub_title'] as String?) ?? '',
      summary: (json['summary'] as String?) ?? '',
      picUrl: (json['pic_url'] as String?) ?? (json['picture'] as String?) ?? '',
      publishTime: (json['publish_time'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'sub_title': subTitle,
    'summary': summary,
    'pic_url': picUrl,
    'publish_time': publishTime,
  };
}
