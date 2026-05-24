import 'dart:convert';
import 'package:http/http.dart' as http;

import 'accessible_place.dart';

class AccessiblePlacesService {
  static const String baseUrl =
      'https://searchaccessibleplaces-vihtwag23a-uc.a.run.app';

  Future<List<AccessiblePlace>> searchPlaces({
    required String query,
    required double userLat,
    required double userLng,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(baseUrl),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'query': query,
              'userLat': userLat,
              'userLng': userLng,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final results = decoded['results'] as List<dynamic>? ?? [];

        final places = results
            .map(
              (item) => AccessiblePlace.fromJson(item as Map<String, dynamic>),
            )
            .toList();

        if (places.isNotEmpty) {
          return places;
        }
      }

      return _fallbackPlaces(query, userLat, userLng);
    } catch (_) {
      return _fallbackPlaces(query, userLat, userLng);
    }
  }

  List<AccessiblePlace> _fallbackPlaces(
    String query,
    double userLat,
    double userLng,
  ) {
    final lowerQuery = query.toLowerCase();

    String category = 'Accessible Place';

    if (lowerQuery.contains('hospital')) {
      category = 'Hospital';
    } else if (lowerQuery.contains('restaurant')) {
      category = 'Restaurant';
    } else if (lowerQuery.contains('cafe')) {
      category = 'Cafe';
    } else if (lowerQuery.contains('mall')) {
      category = 'Mall';
    } else if (lowerQuery.contains('park')) {
      category = 'Park';
    }

    return [
      AccessiblePlace(
        id: 'fallback_1',
        name: 'Nearby $category 1',
        category: category,
        lat: userLat + 0.004,
        lng: userLng + 0.004,
        distanceKm: 0.6,
        mapsUri: '',
        wheelchairEntrance: true,
        accessibleParking: true,
        accessibleRestroom: true,
        accessibleSeating: true,
        note:
            'Demo accessible place. The online search service is not available now.',
      ),
      AccessiblePlace(
        id: 'fallback_2',
        name: 'Nearby $category 2',
        category: category,
        lat: userLat - 0.004,
        lng: userLng + 0.003,
        distanceKm: 0.9,
        mapsUri: '',
        wheelchairEntrance: true,
        accessibleParking: true,
        accessibleRestroom: false,
        accessibleSeating: true,
        note: 'Demo accessible place with basic accessibility information.',
      ),
      AccessiblePlace(
        id: 'fallback_3',
        name: 'Nearby $category 3',
        category: category,
        lat: userLat + 0.003,
        lng: userLng - 0.004,
        distanceKm: 1.2,
        mapsUri: '',
        wheelchairEntrance: true,
        accessibleParking: false,
        accessibleRestroom: true,
        accessibleSeating: true,
        note: 'Demo result shown because the search service failed.',
      ),
    ];
  }
}
