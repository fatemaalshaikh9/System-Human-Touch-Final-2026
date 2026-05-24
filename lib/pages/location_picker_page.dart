import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_settings_store.dart';

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final Completer<GoogleMapController> _mapController = Completer();

  static const LatLng _defaultLocation = LatLng(26.2235, 50.5876);
  static const Color _mainBlue = Color(0xFF87CEEB);

  LatLng _selectedLocation = _defaultLocation;

  bool _isLoading = true;

  String _locationText = '';

  bool get isArabic => AppSettingsStore.instance.isArabic;

  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;

  Color get cardColor => Theme.of(context).cardColor;

  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF14181B);

  Color get subTextColor =>
      Theme.of(context).textTheme.bodyMedium?.color ?? const Color(0xFF14181B);

  Color get borderColor => Theme.of(context).dividerColor;

  String tr(String en, String ar) => isArabic ? ar : en;

  bool get isSmallScreen {
    final width = MediaQuery.maybeOf(context)?.size.width ?? 400;
    return width < 380;
  }

  @override
  void initState() {
    super.initState();

    AppSettingsStore.instance.addListener(_onSettingsChanged);

    _locationText = tr('Selected Location', 'الموقع المحدد');

    _initializeLocation();
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {
        if (_locationText == 'Selected Location' ||
            _locationText == 'الموقع المحدد') {
          _locationText = tr(
            'Selected Location',
            'الموقع المحدد',
          );
        } else {
          _locationText = _formatLocationText(_selectedLocation);
        }
      });
    }
  }

  @override
  void dispose() {
    AppSettingsStore.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  String _formatLocationText(LatLng location) {
    return tr(
      'Lat: ${location.latitude.toStringAsFixed(5)}, Lng: ${location.longitude.toStringAsFixed(5)}',
      'خط العرض: ${location.latitude.toStringAsFixed(5)}، خط الطول: ${location.longitude.toStringAsFixed(5)}',
    );
  }

  Future<void> _initializeLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!mounted) return;

      if (!serviceEnabled) {
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (!mounted) return;

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        if (!mounted) return;
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _isLoading = false);
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      final LatLng currentLocation = LatLng(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _selectedLocation = currentLocation;
        _locationText = _formatLocationText(currentLocation);
        _isLoading = false;
      });

      final controller = await _mapController.future;

      if (!mounted) return;

      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: currentLocation,
            zoom: 16,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _isLoading = false);
    }
  }

  Future<void> _goToCurrentLocation() async {
    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      final LatLng currentLocation = LatLng(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _selectedLocation = currentLocation;
        _locationText = _formatLocationText(currentLocation);
      });

      final controller = await _mapController.future;

      if (!mounted) return;

      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: currentLocation,
            zoom: 16,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Unable to get current location',
              'تعذر الحصول على الموقع الحالي',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _saveLocationLog() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await FirebaseFirestore.instance.collection('location_logs').add({
      'userId': user.uid,
      'address': _locationText,
      'latitude': _selectedLocation.latitude,
      'longitude': _selectedLocation.longitude,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _confirmLocation() async {
    await _saveLocationLog();

    if (!mounted) return;

    Navigator.pop(
      context,
      {
        'address': _locationText,
        'latitude': _selectedLocation.latitude,
        'longitude': _selectedLocation.longitude,
      },
    );
  }

  void _goBack() {
    Navigator.pop(context);
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

  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: isSmallScreen ? 115 : 130,
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
              IconButton(
                onPressed: _goBack,
                icon: Icon(
                  isArabic ? Icons.arrow_forward : Icons.arrow_back,
                  size: 28,
                  color: textColor,
                ),
              ),
              Expanded(
                child: Text(
                  tr('Pick Location', 'اختيار الموقع'),
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
              const SizedBox(width: 48),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationBottomCard() {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: _shadow(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _locationText,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isSmallScreen ? 13 : 14,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: isSmallScreen ? 46 : 50,
            child: ElevatedButton(
              onPressed: _confirmLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: _mainBlue,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                tr(
                  'Confirm Location',
                  'تأكيد الموقع',
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapContent(Marker marker) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _selectedLocation,
            zoom: 14,
          ),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          markers: {marker},
          onMapCreated: (GoogleMapController controller) {
            if (!_mapController.isCompleted) {
              _mapController.complete(controller);
            }
          },
          onTap: (LatLng tappedLocation) {
            if (!mounted) return;

            setState(() {
              _selectedLocation = tappedLocation;
              _locationText = _formatLocationText(tappedLocation);
            });
          },
        ),
        Positioned(
          top: 16,
          right: isArabic ? null : 16,
          left: isArabic ? 16 : null,
          child: FloatingActionButton(
            heroTag: 'current_location_btn',
            mini: true,
            backgroundColor: cardColor,
            onPressed: _goToCurrentLocation,
            child: Icon(
              Icons.my_location,
              color: textColor,
            ),
          ),
        ),
        Positioned(
          left: isSmallScreen ? 12 : 16,
          right: isSmallScreen ? 12 : 16,
          bottom: isSmallScreen ? 12 : 20,
          child: _buildLocationBottomCard(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final marker = Marker(
      markerId: const MarkerId('selected_location'),
      position: _selectedLocation,
      draggable: true,
      onDragEnd: (LatLng newPosition) {
        if (!mounted) return;

        setState(() {
          _selectedLocation = newPosition;
          _locationText = _formatLocationText(newPosition);
        });
      },
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
            child: Scaffold(
              resizeToAvoidBottomInset: true,
              backgroundColor: backgroundColor,
              body: SafeArea(
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF87CEEB),
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                return SizedBox(
                                  width: constraints.maxWidth,
                                  height: constraints.maxHeight,
                                  child: _buildMapContent(marker),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
