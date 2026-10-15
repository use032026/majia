// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CardItemImpl _$$CardItemImplFromJson(Map<String, dynamic> json) =>
    _$CardItemImpl(
      cardId: json['cardId'] as String,
      cardStyle: json['cardStyle'] as String,
      isShow: json['isShow'] as bool,
      title: json['title'] as String?,
      bgColor: json['bgColor'] as String?,
      cardType: json['cardType'] as String?,
      link: json['link'] as String?,
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble(),
      cardDetail: json['cardDetail'] as Map<String, dynamic>?,
      showPermission:
          (json['showPermission'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$CardItemImplToJson(_$CardItemImpl instance) =>
    <String, dynamic>{
      'cardId': instance.cardId,
      'cardStyle': instance.cardStyle,
      'isShow': instance.isShow,
      'title': instance.title,
      'bgColor': instance.bgColor,
      'cardType': instance.cardType,
      'link': instance.link,
      'aspectRatio': instance.aspectRatio,
      'cardDetail': instance.cardDetail,
      'showPermission': instance.showPermission,
    };
