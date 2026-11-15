class Place {
  const Place({
    required this.id,
    required this.name,
    required this.address,
    this.category = '주요 장소',
    this.supported = true,
    this.latitude,
    this.longitude,
    this.provider,
    this.externalId,
  });
  final String id;
  final String name;
  final String address;
  final String category;
  final bool supported;
  final double? latitude, longitude;
  final String? provider, externalId;
  bool get hasCoordinates => latitude != null && longitude != null;
  factory Place.fromJson(Map<String, dynamic> json) {
    final lat = (json['latitude'] ?? json['lat']) as num?;
    final lon = (json['longitude'] ?? json['lon']) as num?;
    return Place(
      id: '${json['provider'] ?? 'coordinate'}:${json['externalId'] ?? '$lat,$lon'}',
      name: json['name'] as String? ?? '선택 위치',
      address: json['address'] as String? ?? '',
      latitude: lat?.toDouble(),
      longitude: lon?.toDouble(),
      provider: json['provider'] as String?,
      externalId: json['externalId'] as String?,
    );
  }
  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'name': name,
    'address': address,
    if (provider != null) 'provider': provider,
    if (externalId != null) 'externalId': externalId,
  };
}
