// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'card_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

CardItem _$CardItemFromJson(Map<String, dynamic> json) {
  return _CardItem.fromJson(json);
}

/// @nodoc
mixin _$CardItem {
  String get cardId => throw _privateConstructorUsedError;
  String get cardStyle => throw _privateConstructorUsedError;
  bool get isShow => throw _privateConstructorUsedError;
  String? get title => throw _privateConstructorUsedError;
  String? get bgColor => throw _privateConstructorUsedError;
  String? get cardType =>
      throw _privateConstructorUsedError; // native / web / mini
  String? get link => throw _privateConstructorUsedError;
  double? get aspectRatio => throw _privateConstructorUsedError;
  Map<String, dynamic>? get cardDetail => throw _privateConstructorUsedError;
  List<String> get showPermission => throw _privateConstructorUsedError;

  /// Serializes this CardItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CardItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CardItemCopyWith<CardItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CardItemCopyWith<$Res> {
  factory $CardItemCopyWith(CardItem value, $Res Function(CardItem) then) =
      _$CardItemCopyWithImpl<$Res, CardItem>;
  @useResult
  $Res call({
    String cardId,
    String cardStyle,
    bool isShow,
    String? title,
    String? bgColor,
    String? cardType,
    String? link,
    double? aspectRatio,
    Map<String, dynamic>? cardDetail,
    List<String> showPermission,
  });
}

/// @nodoc
class _$CardItemCopyWithImpl<$Res, $Val extends CardItem>
    implements $CardItemCopyWith<$Res> {
  _$CardItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CardItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? cardId = null,
    Object? cardStyle = null,
    Object? isShow = null,
    Object? title = freezed,
    Object? bgColor = freezed,
    Object? cardType = freezed,
    Object? link = freezed,
    Object? aspectRatio = freezed,
    Object? cardDetail = freezed,
    Object? showPermission = null,
  }) {
    return _then(
      _value.copyWith(
            cardId: null == cardId
                ? _value.cardId
                : cardId // ignore: cast_nullable_to_non_nullable
                      as String,
            cardStyle: null == cardStyle
                ? _value.cardStyle
                : cardStyle // ignore: cast_nullable_to_non_nullable
                      as String,
            isShow: null == isShow
                ? _value.isShow
                : isShow // ignore: cast_nullable_to_non_nullable
                      as bool,
            title: freezed == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String?,
            bgColor: freezed == bgColor
                ? _value.bgColor
                : bgColor // ignore: cast_nullable_to_non_nullable
                      as String?,
            cardType: freezed == cardType
                ? _value.cardType
                : cardType // ignore: cast_nullable_to_non_nullable
                      as String?,
            link: freezed == link
                ? _value.link
                : link // ignore: cast_nullable_to_non_nullable
                      as String?,
            aspectRatio: freezed == aspectRatio
                ? _value.aspectRatio
                : aspectRatio // ignore: cast_nullable_to_non_nullable
                      as double?,
            cardDetail: freezed == cardDetail
                ? _value.cardDetail
                : cardDetail // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            showPermission: null == showPermission
                ? _value.showPermission
                : showPermission // ignore: cast_nullable_to_non_nullable
                      as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CardItemImplCopyWith<$Res>
    implements $CardItemCopyWith<$Res> {
  factory _$$CardItemImplCopyWith(
    _$CardItemImpl value,
    $Res Function(_$CardItemImpl) then,
  ) = __$$CardItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String cardId,
    String cardStyle,
    bool isShow,
    String? title,
    String? bgColor,
    String? cardType,
    String? link,
    double? aspectRatio,
    Map<String, dynamic>? cardDetail,
    List<String> showPermission,
  });
}

/// @nodoc
class __$$CardItemImplCopyWithImpl<$Res>
    extends _$CardItemCopyWithImpl<$Res, _$CardItemImpl>
    implements _$$CardItemImplCopyWith<$Res> {
  __$$CardItemImplCopyWithImpl(
    _$CardItemImpl _value,
    $Res Function(_$CardItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CardItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? cardId = null,
    Object? cardStyle = null,
    Object? isShow = null,
    Object? title = freezed,
    Object? bgColor = freezed,
    Object? cardType = freezed,
    Object? link = freezed,
    Object? aspectRatio = freezed,
    Object? cardDetail = freezed,
    Object? showPermission = null,
  }) {
    return _then(
      _$CardItemImpl(
        cardId: null == cardId
            ? _value.cardId
            : cardId // ignore: cast_nullable_to_non_nullable
                  as String,
        cardStyle: null == cardStyle
            ? _value.cardStyle
            : cardStyle // ignore: cast_nullable_to_non_nullable
                  as String,
        isShow: null == isShow
            ? _value.isShow
            : isShow // ignore: cast_nullable_to_non_nullable
                  as bool,
        title: freezed == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String?,
        bgColor: freezed == bgColor
            ? _value.bgColor
            : bgColor // ignore: cast_nullable_to_non_nullable
                  as String?,
        cardType: freezed == cardType
            ? _value.cardType
            : cardType // ignore: cast_nullable_to_non_nullable
                  as String?,
        link: freezed == link
            ? _value.link
            : link // ignore: cast_nullable_to_non_nullable
                  as String?,
        aspectRatio: freezed == aspectRatio
            ? _value.aspectRatio
            : aspectRatio // ignore: cast_nullable_to_non_nullable
                  as double?,
        cardDetail: freezed == cardDetail
            ? _value._cardDetail
            : cardDetail // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        showPermission: null == showPermission
            ? _value._showPermission
            : showPermission // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CardItemImpl implements _CardItem {
  const _$CardItemImpl({
    required this.cardId,
    required this.cardStyle,
    required this.isShow,
    this.title,
    this.bgColor,
    this.cardType,
    this.link,
    this.aspectRatio,
    final Map<String, dynamic>? cardDetail,
    final List<String> showPermission = const [],
  }) : _cardDetail = cardDetail,
       _showPermission = showPermission;

  factory _$CardItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$CardItemImplFromJson(json);

  @override
  final String cardId;
  @override
  final String cardStyle;
  @override
  final bool isShow;
  @override
  final String? title;
  @override
  final String? bgColor;
  @override
  final String? cardType;
  // native / web / mini
  @override
  final String? link;
  @override
  final double? aspectRatio;
  final Map<String, dynamic>? _cardDetail;
  @override
  Map<String, dynamic>? get cardDetail {
    final value = _cardDetail;
    if (value == null) return null;
    if (_cardDetail is EqualUnmodifiableMapView) return _cardDetail;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  final List<String> _showPermission;
  @override
  @JsonKey()
  List<String> get showPermission {
    if (_showPermission is EqualUnmodifiableListView) return _showPermission;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_showPermission);
  }

  @override
  String toString() {
    return 'CardItem(cardId: $cardId, cardStyle: $cardStyle, isShow: $isShow, title: $title, bgColor: $bgColor, cardType: $cardType, link: $link, aspectRatio: $aspectRatio, cardDetail: $cardDetail, showPermission: $showPermission)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CardItemImpl &&
            (identical(other.cardId, cardId) || other.cardId == cardId) &&
            (identical(other.cardStyle, cardStyle) ||
                other.cardStyle == cardStyle) &&
            (identical(other.isShow, isShow) || other.isShow == isShow) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.bgColor, bgColor) || other.bgColor == bgColor) &&
            (identical(other.cardType, cardType) ||
                other.cardType == cardType) &&
            (identical(other.link, link) || other.link == link) &&
            (identical(other.aspectRatio, aspectRatio) ||
                other.aspectRatio == aspectRatio) &&
            const DeepCollectionEquality().equals(
              other._cardDetail,
              _cardDetail,
            ) &&
            const DeepCollectionEquality().equals(
              other._showPermission,
              _showPermission,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    cardId,
    cardStyle,
    isShow,
    title,
    bgColor,
    cardType,
    link,
    aspectRatio,
    const DeepCollectionEquality().hash(_cardDetail),
    const DeepCollectionEquality().hash(_showPermission),
  );

  /// Create a copy of CardItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CardItemImplCopyWith<_$CardItemImpl> get copyWith =>
      __$$CardItemImplCopyWithImpl<_$CardItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CardItemImplToJson(this);
  }
}

abstract class _CardItem implements CardItem {
  const factory _CardItem({
    required final String cardId,
    required final String cardStyle,
    required final bool isShow,
    final String? title,
    final String? bgColor,
    final String? cardType,
    final String? link,
    final double? aspectRatio,
    final Map<String, dynamic>? cardDetail,
    final List<String> showPermission,
  }) = _$CardItemImpl;

  factory _CardItem.fromJson(Map<String, dynamic> json) =
      _$CardItemImpl.fromJson;

  @override
  String get cardId;
  @override
  String get cardStyle;
  @override
  bool get isShow;
  @override
  String? get title;
  @override
  String? get bgColor;
  @override
  String? get cardType; // native / web / mini
  @override
  String? get link;
  @override
  double? get aspectRatio;
  @override
  Map<String, dynamic>? get cardDetail;
  @override
  List<String> get showPermission;

  /// Create a copy of CardItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CardItemImplCopyWith<_$CardItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
