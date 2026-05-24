class AccessiblePlace {
  final String id;
  final String name;
  final String category;
  final double lat;
  final double lng;
  final double distanceKm;
  final bool wheelchairEntrance;
  final bool accessibleParking;
  final bool accessibleRestroom;
  final bool accessibleSeating;
  final String note;
  final String mapsUri;

  AccessiblePlace({
    required this.id,
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    required this.distanceKm,
    required this.wheelchairEntrance,
    required this.accessibleParking,
    required this.accessibleRestroom,
    required this.accessibleSeating,
    required this.note,
    required this.mapsUri,
  });

  factory AccessiblePlace.fromJson(Map<String, dynamic> json) {
    return AccessiblePlace(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
      distanceKm: (json['distanceKm'] ?? 0).toDouble(),
      wheelchairEntrance: json['wheelchairEntrance'] == true,
      accessibleParking: json['accessibleParking'] == true,
      accessibleRestroom: json['accessibleRestroom'] == true,
      accessibleSeating: json['accessibleSeating'] == true,
      note: (json['note'] ?? '').toString(),
      mapsUri: (json['mapsUri'] ?? '').toString(),
    );
  }
}
