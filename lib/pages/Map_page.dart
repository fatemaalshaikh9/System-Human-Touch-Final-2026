import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'accessible_place.dart';
import 'accessible_places_service.dart';
import 'Dashboard_page.dart';
import 'Profile_page.dart';
import 'Settings_page.dart';
import 'Reminders_page.dart';
import 'Health_page.dart';
import 'Communication_page.dart';
import 'Emergency_page.dart';
import 'VolunteerHelp_page.dart';
import 'voice_accessibility_service.dart';

import 'package:humantouch/pages/app_settings_store.dart';

class AiMessage {
  final String text;
  final bool isAi;

  AiMessage({required this.text, required this.isAi});
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final TextEditingController _searchController = TextEditingController();
  final AccessiblePlacesService _placesService = AccessiblePlacesService();

  GoogleMapController? _mapController;
  Position? _currentPosition;

  bool _isLoadingLocation = true;
  bool _isSearching = false;
  bool _voiceAssistantStarted = false;
  bool _isSpeaking = false;

  bool get isAccessibilityVoiceEnabled {
    final settings = AppSettingsStore.instance as dynamic;

    try {
      if (settings.isAccessibilityVoiceEnabled == true) return true;
    } catch (_) {}

    try {
      if (settings.accessibilityVoiceEnabled == true) return true;
    } catch (_) {}

    try {
      if (settings.voiceAccessibilityEnabled == true) return true;
    } catch (_) {}

    try {
      if (settings.accessibilityVoice == true) return true;
    } catch (_) {}

    return false;
  }

  AccessiblePlace? _selectedPlace;

  final List<AiMessage> _messages = [];

  List<AccessiblePlace> _results = [];
  Set<Marker> _markers = {};

  static const Color _mainBlue = Color(0xFF87CEEB);

  bool get isArabic => AppSettingsStore.instance.isArabic;

  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;

  Color get cardColor => Theme.of(context).cardColor;

  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

  Color get subTextColor =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;

  Color get borderColor => Theme.of(context).dividerColor;

  String tr(String en, String ar) => isArabic ? ar : en;

  bool get isSmallScreen {
    final width = MediaQuery.maybeOf(context)?.size.width ?? 400;
    return width < 380;
  }

  void _moveCamera(LatLng target, {double zoom = 14}) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          zoom: zoom,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _messages.add(
      AiMessage(
        text: tr(
          'Hello 👋 Tell me where you want to go, and I will suggest accessible places near you.',
          'مرحباً 👋 أخبرني إلى أين تريد الذهاب، وسأقترح لك أماكن مناسبة قريبة منك.',
        ),
        isAi: true,
      ),
    );

    AppSettingsStore.instance.addListener(_onLanguageChanged);
    _getCurrentLocation();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && isAccessibilityVoiceEnabled) {
        await _startVoiceAccessibilityAssistant();
      }
    });
  }

  Future<void> _startVoiceAccessibilityAssistant() async {
    if (!mounted) return;

    await VoiceAccessibilityService.instance.stopAll();

    setState(() {
      _isSpeaking = true;
    });

    await VoiceAccessibilityService.instance.readPageAndListen(
      context: context,
      pageText: tr(
        'Accessible Map screen with AI location assistant. You can press the restaurant, cafe, hospital, mall, or park buttons to show accessible places on the map, or type a place in the text field to search using AI. Pressing a location on the map opens a Google Maps link for directions to that place. Home, profile, and settings options are available.',
        'صفحة الخريطة الميسّرة تحتوي على مساعد مواقع بالذكاء الاصطناعي. يمكنك الضغط على أزرار المطعم أو المقهى أو المستشفى أو المجمع أو الحديقة لإظهار الأماكن المناسبة على الخريطة، أو كتابة مكان في حقل البحث للبحث باستخدام الذكاء الاصطناعي. الضغط على أي موقع في الخريطة يفتح رابط خرائط جوجل للاتجاهات إلى ذلك المكان. تتوفر أيضًا خيارات الرئيسية والملف الشخصي والإعدادات.',
      ),
      routes: {
        'dashboard': (context) => const DashboardPage(),
        'health': (context) => const HealthPage(),
        'reminders': (context) => const RemindersPage(),
        'emergency': (context) => const EmergencyPage(),
        'communication': (context) => const CommunicationPage(),
        'map': (context) => const MapPage(),
        'volunteer': (context) => const VolunteerHelpPage(),
        'profile': (context) => const ProfilePage(),
        'settings': (context) => const SettingsPage(),
      },
    );

    if (!mounted) return;

    setState(() {
      _isSpeaking = false;
    });
  }

  Future<void> _stopSpeaking() async {
    await VoiceAccessibilityService.instance.stopAll();

    if (!mounted) return;

    setState(() {
      _isSpeaking = false;
    });
  }

  Future<void> _toggleVoiceButton() async {
    if (_isSpeaking) {
      await _stopSpeaking();
    } else {
      await _startVoiceAccessibilityAssistant();
    }
  }

  Widget _voiceControlButton() {
    return Positioned(
      left: 18,
      bottom: 18,
      child: Semantics(
        button: true,
        label: _isSpeaking
            ? tr('Stop voice reading', 'إيقاف القراءة الصوتية')
            : tr('Read this page again', 'إعادة قراءة الصفحة'),
        child: GestureDetector(
          onTap: _toggleVoiceButton,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: _isSpeaking
                  ? const Color(0xFF87CEEB)
                  : const Color(0xFFFF5A5F),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              _isSpeaking
                  ? Icons.record_voice_over_rounded
                  : Icons.volume_off_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppSettingsStore.instance.removeListener(_onLanguageChanged);
    VoiceAccessibilityService.instance.stopAll();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  String quickChipLabel(String label) {
    switch (label) {
      case 'Restaurant':
        return tr('Restaurant', 'مطعم');
      case 'Cafe':
        return tr('Cafe', 'مقهى');
      case 'Hospital':
        return tr('Hospital', 'مستشفى');
      case 'Mall':
        return tr('Mall', 'مجمع');
      case 'Park':
        return tr('Park', 'حديقة');
      default:
        return label;
    }
  }

  String tagText(String text) {
    switch (text) {
      case 'Entrance':
        return tr('Entrance', 'مدخل');
      case 'Parking':
        return tr('Parking', 'مواقف');
      case 'Restroom':
        return tr('Restroom', 'دورة مياه');
      case 'Seating':
        return tr('Seating', 'جلسات');
      default:
        return text;
    }
  }

  Future<void> _saveSearchLog({
    required String query,
    required int resultCount,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('map_search_logs').add({
      'userId': user.uid,
      'query': query,
      'resultCount': resultCount,
      'userLat': _currentPosition?.latitude,
      'userLng': _currentPosition?.longitude,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _saveSelectedPlace({
    required AccessiblePlace place,
    required String action,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('selected_accessible_places')
        .add({
      'userId': user.uid,
      'action': action,
      'placeId': place.id,
      'name': place.name,
      'category': place.category,
      'lat': place.lat,
      'lng': place.lng,
      'distanceKm': place.distanceKm,
      'mapsUri': place.mapsUri,
      'wheelchairEntrance': place.wheelchairEntrance,
      'accessibleParking': place.accessibleParking,
      'accessibleRestroom': place.accessibleRestroom,
      'accessibleSeating': place.accessibleSeating,
      'note': place.note,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void _goBack() {
    VoiceAccessibilityService.instance.stopAll();

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardPage()),
      );
    }
  }

  void _goToPage(int index) {
    VoiceAccessibilityService.instance.stopAll();

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      );
    }
  }

  Widget _bottomItem(IconData icon, String label, int index) {
    return Flexible(
      child: Semantics(
        button: true,
        label: label,
        hint: tr(
          'Double tap to open $label page',
          'اضغط مرتين لفتح صفحة $label',
        ),
        child: GestureDetector(
          onTap: () => _goToPage(index),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 27),
              const SizedBox(height: 3),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<BoxShadow> _shadow() {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.08),
        blurRadius: 12,
        offset: const Offset(0, 5),
      ),
    ];
  }

  Widget _buildBottomNavigation() {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: _mainBlue,
          borderRadius: BorderRadius.circular(26),
          boxShadow: _shadow(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _bottomItem(Icons.home_rounded, tr('Home', 'الرئيسية'), 0),
            _bottomItem(Icons.person_rounded, tr('Profile', 'الملف'), 1),
            _bottomItem(Icons.settings_rounded, tr('Settings', 'الإعدادات'), 2),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 140,
              width: double.infinity,
              color: _mainBlue,
            ),
            Container(
              height: 40,
              width: double.infinity,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(40),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: tr('Back button', 'زر الرجوع'),
                hint: tr(
                  'Double tap to go back',
                  'اضغط مرتين للرجوع',
                ),
                child: IconButton(
                  onPressed: _goBack,
                  icon: Icon(
                    isArabic ? Icons.arrow_forward : Icons.arrow_back,
                    size: 28,
                    color: textColor,
                  ),
                ),
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  label: tr('Accessible Map page', 'صفحة الخريطة الميسّرة'),
                  child: Text(
                    tr('Accessible Map', 'الخريطة الميسّرة'),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 21 : 25,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        setState(() => _isLoadingLocation = false);

        _addAiMessage(
          tr(
            'Please turn on location services first.',
            'يرجى تشغيل خدمات الموقع أولاً.',
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        setState(() => _isLoadingLocation = false);

        _addAiMessage(
          tr(
            'Location permission is required to suggest nearby places.',
            'إذن الموقع مطلوب لاقتراح أماكن قريبة.',
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition();

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
        _markers = {
          Marker(
            markerId: const MarkerId('my_location'),
            position: LatLng(position.latitude, position.longitude),
            infoWindow: InfoWindow(title: tr('My Location', 'موقعي')),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
          ),
        };
      });

      _moveCamera(LatLng(position.latitude, position.longitude), zoom: 14);
    } catch (_) {
      if (!mounted) return;

      setState(() => _isLoadingLocation = false);

      _addAiMessage(
        tr(
          'Failed to get your location.',
          'فشل الحصول على موقعك.',
        ),
      );
    }
  }

  void _addAiMessage(String text) {
    setState(() {
      _messages.add(AiMessage(text: text, isAi: true));
    });
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(AiMessage(text: text, isAi: false));
    });
  }

  Future<void> _searchByPrompt(String prompt) async {
    if (_currentPosition == null) {
      _addAiMessage(
        tr(
          'I still need your current location first.',
          'ما زلت أحتاج إلى موقعك الحالي أولاً.',
        ),
      );
      return;
    }

    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return;

    _addUserMessage(trimmed);
    _searchController.clear();

    setState(() {
      _isSearching = true;
      _selectedPlace = null;
      _results = [];
    });

    try {
      final places = await _placesService.searchPlaces(
        query: trimmed,
        userLat: _currentPosition!.latitude,
        userLng: _currentPosition!.longitude,
      );

      await _saveSearchLog(query: trimmed, resultCount: places.length);

      final markers = <Marker>{
        Marker(
          markerId: const MarkerId('my_location'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          infoWindow: InfoWindow(title: tr('My Location', 'موقعي')),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
        ...places.map(
          (place) => Marker(
            markerId: MarkerId(place.id),
            position: LatLng(place.lat, place.lng),
            infoWindow: InfoWindow(
              title: place.name,
              snippet:
                  '${place.category} • ${place.distanceKm.toStringAsFixed(1)} km',
            ),
            onTap: () {
              setState(() {
                _selectedPlace = place;
              });
              _saveSelectedPlace(place: place, action: 'marker_tap');
            },
          ),
        ),
      };

      if (!mounted) return;

      setState(() {
        _results = places;
        _markers = markers;
        _isSearching = false;
      });

      if (places.isEmpty) {
        _addAiMessage(
          tr(
            'I could not find accessible places for that request.',
            'لم أتمكن من العثور على أماكن ميسّرة لهذا الطلب.',
          ),
        );

        await VoiceAccessibilityService.instance.speak(
          tr(
            'I could not find accessible places for that request.',
            'لم أتمكن من العثور على أماكن ميسّرة لهذا الطلب.',
          ),
        );
        return;
      }

      _addAiMessage(
        tr(
          'I found ${places.length} accessible options near you. Choose one and I will open its location.',
          'وجدت ${places.length} خيارات ميسّرة بالقرب منك. اختر واحداً وسأفتح موقعه.',
        ),
      );

      await VoiceAccessibilityService.instance.speak(
        tr(
          'I found ${places.length} accessible options near you. The first result is ${places.first.name}, ${places.first.category}, ${places.first.distanceKm.toStringAsFixed(1)} kilometers away. It has ${places.first.wheelchairEntrance ? "accessible entrance, " : ""}${places.first.accessibleParking ? "accessible parking, " : ""}${places.first.accessibleRestroom ? "accessible restroom, " : ""}${places.first.accessibleSeating ? "accessible seating, " : ""}.',
          'وجدت ${places.length} خيارات ميسّرة بالقرب منك. أول نتيجة هي ${places.first.name}، نوعها ${places.first.category}، وتبعد ${places.first.distanceKm.toStringAsFixed(1)} كيلومتر. تحتوي على ${places.first.wheelchairEntrance ? "مدخل مناسب، " : ""}${places.first.accessibleParking ? "مواقف مناسبة، " : ""}${places.first.accessibleRestroom ? "دورة مياه مناسبة، " : ""}${places.first.accessibleSeating ? "جلسات مناسبة، " : ""}.',
        ),
      );

      final first = places.first;
      _moveCamera(LatLng(first.lat, first.lng), zoom: 13.5);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSearching = false;
      });

      _addAiMessage(
        tr(
          'Search failed. Please try again.',
          'فشل البحث. يرجى المحاولة مرة أخرى.',
        ),
      );

      await VoiceAccessibilityService.instance.speak(
        tr(
          'Search failed. Please try again.',
          'فشل البحث. يرجى المحاولة مرة أخرى.',
        ),
      );
    }
  }

  Future<void> _openPlaceInMaps(AccessiblePlace place) async {
    await _saveSelectedPlace(place: place, action: 'open_directions');

    await VoiceAccessibilityService.instance.speak(
      tr(
        'Opening directions from your location to ${place.name} in Google Maps.',
        'جارٍ فتح الاتجاهات من موقعك إلى ${place.name} في خرائط جوجل.',
      ),
    );

    final double? originLat = _currentPosition?.latitude;
    final double? originLng = _currentPosition?.longitude;

    final String originPart = originLat != null && originLng != null
        ? '&origin=$originLat,$originLng'
        : '';

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '$originPart'
      '&destination=${place.lat},${place.lng}'
      '&travelmode=driving',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  Widget _buildQuickChip(String label) {
    return Semantics(
      button: true,
      label: quickChipLabel(label),
      hint: tr(
        'Double tap to search for ${quickChipLabel(label)}',
        'اضغط مرتين للبحث عن ${quickChipLabel(label)}',
      ),
      child: ActionChip(
        backgroundColor: cardColor,
        side: BorderSide(color: borderColor),
        label: Text(
          quickChipLabel(label),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: textColor, fontSize: isSmallScreen ? 12 : 13),
        ),
        onPressed: () => _searchByPrompt(label),
      ),
    );
  }

  Widget _buildMessageBubble(AiMessage message) {
    return Semantics(
      label: message.isAi
          ? tr('AI message: ${message.text}',
              'رسالة الذكاء الاصطناعي: ${message.text}')
          : tr('Your message: ${message.text}', 'رسالتك: ${message.text}'),
      child: Align(
        alignment: message.isAi ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 10 : 12,
            vertical: isSmallScreen ? 8 : 10,
          ),
          constraints: BoxConstraints(
            maxWidth: isSmallScreen ? 220 : 260,
          ),
          decoration: BoxDecoration(
            color: message.isAi ? cardColor : _mainBlue,
            borderRadius: BorderRadius.circular(14),
            border: message.isAi ? Border.all(color: borderColor) : null,
          ),
          child: Text(
            message.text,
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: message.isAi ? textColor : Colors.white,
              fontSize: isSmallScreen ? 12 : 13,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor ??
            const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        tagText(text),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: isSmallScreen ? 10 : 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  String _placeAccessibilityText(AccessiblePlace place) {
    final List<String> features = [];

    if (place.wheelchairEntrance) {
      features.add(tr('accessible entrance', 'مدخل مناسب'));
    }
    if (place.accessibleParking) {
      features.add(tr('accessible parking', 'مواقف مناسبة'));
    }
    if (place.accessibleRestroom) {
      features.add(tr('accessible restroom', 'دورة مياه مناسبة'));
    }
    if (place.accessibleSeating) {
      features.add(tr('accessible seating', 'جلسات مناسبة'));
    }

    final featureText = features.isEmpty
        ? tr('No accessibility features listed', 'لا توجد ميزات وصول مسجلة')
        : features.join(', ');

    return tr(
      '${place.name}. ${place.category}. ${place.distanceKm.toStringAsFixed(1)} kilometers away. Accessibility features: $featureText. Note: ${place.note}. There are two buttons: Select, and Open Map.',
      '${place.name}. ${place.category}. يبعد ${place.distanceKm.toStringAsFixed(1)} كيلومتر. ميزات الوصول: $featureText. ملاحظة: ${place.note}. يوجد زران: اختيار، وفتح الخريطة.',
    );
  }

  Widget _buildPlaceCard(AccessiblePlace place) {
    final isSelected = _selectedPlace?.id == place.id;

    return Semantics(
      container: true,
      label: _placeAccessibilityText(place),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDDF2FB) : cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _mainBlue : borderColor,
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              place.name,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: isSmallScreen ? 14 : 15,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                '${place.category} • ${place.distanceKm.toStringAsFixed(1)} km away',
                '${place.category} • يبعد ${place.distanceKm.toStringAsFixed(1)} كم',
              ),
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: isSmallScreen ? 11 : 12, color: subTextColor),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (place.wheelchairEntrance) _tag('Entrance'),
                if (place.accessibleParking) _tag('Parking'),
                if (place.accessibleRestroom) _tag('Restroom'),
                if (place.accessibleSeating) _tag('Seating'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              place.note,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: isSmallScreen ? 11 : 12, color: subTextColor),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final bool smallCard = constraints.maxWidth < 300;

                if (smallCard) {
                  return Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: _selectPlaceButton(place),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: _openMapButton(place),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: _selectPlaceButton(place)),
                    const SizedBox(width: 8),
                    Expanded(child: _openMapButton(place)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectPlaceButton(AccessiblePlace place) {
    return Semantics(
      button: true,
      label: tr('Select ${place.name}', 'اختيار ${place.name}'),
      hint: tr(
        'Double tap to move the map to this place',
        'اضغط مرتين لتحريك الخريطة إلى هذا المكان',
      ),
      child: ElevatedButton(
        onPressed: () async {
          setState(() {
            _selectedPlace = place;
          });

          await _saveSelectedPlace(
            place: place,
            action: 'select_place',
          );

          await VoiceAccessibilityService.instance.speak(
            tr(
              'Selected ${place.name}. The map moved to this place.',
              'تم اختيار ${place.name}. تم تحريك الخريطة إلى هذا المكان.',
            ),
          );

          _moveCamera(LatLng(place.lat, place.lng), zoom: 15.5);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _mainBlue,
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          tr('Select', 'اختيار'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _openMapButton(AccessiblePlace place) {
    return Semantics(
      button: true,
      label: tr('Open ${place.name} in Google Maps',
          'فتح ${place.name} في خرائط جوجل'),
      hint: tr(
        'Double tap to open directions in Google Maps',
        'اضغط مرتين لفتح الاتجاهات في خرائط جوجل',
      ),
      child: OutlinedButton(
        onPressed: () => _openPlaceInMaps(place),
        style: OutlinedButton.styleFrom(
          foregroundColor: _mainBlue,
          side: const BorderSide(color: _mainBlue),
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          tr('Directions', 'الاتجاهات'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildSearchPanel() {
    return Semantics(
      container: true,
      label: tr(
        'AI search panel. You can choose a quick category or type where you want to go.',
        'لوحة البحث بالذكاء الاصطناعي. يمكنك اختيار تصنيف سريع أو كتابة المكان الذي تريد الذهاب إليه.',
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          isSmallScreen ? 10 : 14,
          isSmallScreen ? 10 : 14,
          isSmallScreen ? 10 : 14,
          isSmallScreen ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              color: Colors.black.withOpacity(0.08),
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: isSmallScreen ? 80 : 95,
              child: ListView(
                children: _messages
                    .take(_messages.length > 3 ? 3 : _messages.length)
                    .map(_buildMessageBubble)
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickChip('Restaurant'),
                  const SizedBox(width: 8),
                  _buildQuickChip('Cafe'),
                  const SizedBox(width: 8),
                  _buildQuickChip('Hospital'),
                  const SizedBox(width: 8),
                  _buildQuickChip('Mall'),
                  const SizedBox(width: 8),
                  _buildQuickChip('Park'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    textField: true,
                    label: tr(
                      'Search field. Tell AI where you want to go.',
                      'حقل البحث. أخبر الذكاء الاصطناعي أين تريد الذهاب.',
                    ),
                    hint: tr(
                      'Type a place such as hospital, restaurant, cafe, mall, or park',
                      'اكتب مكان مثل مستشفى، مطعم، مقهى، مجمع، أو حديقة',
                    ),
                    child: TextField(
                      controller: _searchController,
                      textAlign: isArabic ? TextAlign.right : TextAlign.left,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: tr(
                          'Tell AI where you want to go',
                          'أخبر الذكاء الاصطناعي أين تريد الذهاب',
                        ),
                        hintStyle: TextStyle(color: subTextColor),
                        filled: true,
                        fillColor: cardColor,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: isSmallScreen ? 12 : 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: _searchByPrompt,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: tr('Send search request', 'إرسال طلب البحث'),
                  hint: tr(
                    'Double tap to search for the typed place',
                    'اضغط مرتين للبحث عن المكان المكتوب',
                  ),
                  child: InkWell(
                    onTap: _isSearching
                        ? null
                        : () => _searchByPrompt(_searchController.text),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: isSmallScreen ? 46 : 52,
                      height: isSmallScreen ? 46 : 52,
                      decoration: BoxDecoration(
                        color: _mainBlue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ],
            ),
            if (_results.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: isSmallScreen ? 180 : 220,
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    return _buildPlaceCard(_results[index]);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMapContent(LatLng initialTarget) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Expanded(
            child: Semantics(
              label: tr(
                'Map area. It shows your current location and accessible places near you.',
                'منطقة الخريطة. تعرض موقعك الحالي والأماكن المناسبة القريبة منك.',
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: _isLoadingLocation
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF87CEEB),
                        ),
                      )
                    : GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: initialTarget,
                          zoom: 14,
                        ),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        markers: _markers,
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildSearchPanel(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialTarget = _currentPosition == null
        ? const LatLng(26.2235, 50.5876)
        : LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          );

    return AnimatedBuilder(
      animation: AppSettingsStore.instance,
      builder: (context, _) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: AppSettingsStore.instance.textScale,
          ),
          child: Directionality(
            textDirection:
                isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Scaffold(
                resizeToAvoidBottomInset: true,
                backgroundColor: backgroundColor,
                body: Stack(
                  children: [
                    SafeArea(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Column(
                            children: [
                              _buildHeader(),
                              Expanded(
                                child: SizedBox(
                                  width: constraints.maxWidth,
                                  child: _buildMapContent(initialTarget),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    _voiceControlButton(),
                  ],
                ),
                bottomNavigationBar: _buildBottomNavigation(),
              ),
            ),
          ),
        );
      },
    );
  }
}
