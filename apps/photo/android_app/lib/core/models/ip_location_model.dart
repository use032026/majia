/// IP 定位（对齐 iOS `STIpLocationModel`）
class IpLocationModel {
  const IpLocationModel({
    this.location = '',
    this.country = '',
    this.province = '',
    this.city = '',
    this.isoCode = '',
    this.areaCode = '',
  });

  final String location;
  final String country;
  final String province;
  final String city;
  /// ISO 3166-1 两位字母，如 CN / US / HK
  final String isoCode;
  final String areaCode;

  factory IpLocationModel.fromJson(Map<String, dynamic> json) {
    return IpLocationModel(
      location: '${json['location'] ?? ''}',
      country: '${json['country'] ?? ''}',
      province: '${json['province'] ?? ''}',
      city: '${json['city'] ?? ''}',
      isoCode: '${json['iso_code'] ?? ''}',
      areaCode: '${json['area_code'] ?? ''}',
    );
  }
}
