class Place {
  const Place({
    required this.id,
    required this.name,
    required this.address,
    this.category = '주요 장소',
    this.supported = true,
  });
  final String id;
  final String name;
  final String address;
  final String category;
  final bool supported;
}
