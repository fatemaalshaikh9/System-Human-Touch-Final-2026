import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'Dashboard_page.dart';
import 'VolunteerHelpInfo_page.dart';
import 'Profile_page.dart';
import 'Settings_page.dart';

import 'package:humantouch/pages/app_settings_store.dart';
import 'voice_accessibility_service.dart';

class VolunteerHelpPage extends StatefulWidget {
  const VolunteerHelpPage({super.key});

  @override
  State<VolunteerHelpPage> createState() => _VolunteerHelpPageState();
}

class _VolunteerHelpPageState extends State<VolunteerHelpPage> {
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';

  String _selectedSort = 'A-Z';
  String _selectedStatus = 'All';
  String _selectedCategory = 'All';
  String _selectedDistance = 'All';

  bool _showFavoritesOnly = false;
  bool _isSpeaking = false;

  List<String> _favoriteIds = [];

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

  final List<String> _sortOptions = [
    'A-Z',
    'Z-A',
  ];

  final List<String> _statusOptions = [
    'All',
    'Available',
    'Busy',
  ];

  final List<String> _categoryOptions = [
    'All',
    'Medical',
    'Shopping',
    'Transportation',
    'Daily Support',
    'Other',
  ];

  final List<String> _distanceOptions = [
    'All',
    '1 km',
    '5 km',
    '10 km',
    '20 km',
  ];

  bool get isArabic => AppSettingsStore.instance.isArabic;

  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;

  Color get fieldColor =>
      Theme.of(context).inputDecorationTheme.fillColor ?? Colors.white;

  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

  Color get subTextColor => Colors.black54;

  String tr(String en, String ar) => isArabic ? ar : en;

  String optionText(String value) {
    switch (value) {
      case 'All':
        return tr('All', 'الكل');
      case 'Available':
        return tr('Available', 'متاح');
      case 'Busy':
        return tr('Busy', 'مشغول');
      case 'Medical':
        return tr('Medical', 'طبي');
      case 'Shopping':
        return tr('Shopping', 'تسوق');
      case 'Transportation':
        return tr('Transportation', 'مواصلات');
      case 'Daily Support':
        return tr('Daily Support', 'دعم يومي');
      case 'Other':
        return tr('Other', 'أخرى');
      case 'A-Z':
        return tr('A to Z', 'من A إلى Z');
      case 'Z-A':
        return tr('Z to A', 'من Z إلى A');
      default:
        return value;
    }
  }

  String availabilityText(bool isAvailable) {
    return isAvailable ? tr('Available', 'متاح') : tr('Busy', 'مشغول');
  }

  String genderText(String gender) {
    final value = gender.toLowerCase();

    if (value == 'male' || value == 'm' || value == 'ذكر') {
      return tr('Male', 'ذكر');
    }

    if (value == 'female' || value == 'f' || value == 'أنثى') {
      return tr('Female', 'أنثى');
    }

    return tr('Not specified', 'غير محدد');
  }

  IconData genderIcon(String gender) {
    final value = gender.toLowerCase();

    if (value == 'male' || value == 'm' || value == 'ذكر') {
      return Icons.male_rounded;
    }

    if (value == 'female' || value == 'f' || value == 'أنثى') {
      return Icons.female_rounded;
    }

    return Icons.person_outline_rounded;
  }

  Color genderColor(String gender) {
    final value = gender.toLowerCase();

    if (value == 'male' || value == 'm' || value == 'ذكر') {
      return const Color(0xFF1E88E5);
    }

    if (value == 'female' || value == 'f' || value == 'أنثى') {
      return const Color(0xFFE53935);
    }

    return Colors.grey;
  }

  Color cardBackgroundColor(bool isAvailable) {
    return isAvailable ? const Color(0xFFC5E7F5) : const Color(0xFFFFD6D6);
  }

  Color cardTitleColor(bool isAvailable) {
    return isAvailable ? const Color(0xFF025590) : const Color(0xFFD32F2F);
  }

  Color statusBackgroundColor(bool isAvailable) {
    return isAvailable ? const Color(0xFFDDF5E7) : const Color(0xFFFFE1E1);
  }

  Color statusTextColor(bool isAvailable) {
    return isAvailable ? const Color(0xFF2E9E52) : const Color(0xFFD32F2F);
  }

  String helpTypeText(String value) {
    switch (value) {
      case 'Medical':
        return tr('Medical Assistance', 'مساعدة طبية');
      case 'Shopping':
        return tr('Shopping Assistance', 'مساعدة تسوق');
      case 'Transportation':
        return tr('Transportation Support', 'دعم المواصلات');
      case 'Daily Support':
        return tr('Daily Support', 'دعم يومي');
      case 'Other':
        return tr('Other Support', 'دعم آخر');
      default:
        return value;
    }
  }

  @override
  void initState() {
    super.initState();

    AppSettingsStore.instance.addListener(_onLanguageChanged);

    _loadFavoritesFromFirebase();

    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.trim().toLowerCase();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && isAccessibilityVoiceEnabled) {
        await _startVoiceAccessibilityAssistant();
      }
    });
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    AppSettingsStore.instance.removeListener(_onLanguageChanged);
    VoiceAccessibilityService.instance.stopAll();

    _searchController.dispose();

    super.dispose();
  }

  Future<void> _loadFavoritesFromFirebase() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) return;

    final data = doc.data() ?? {};

    setState(() {
      _favoriteIds = List<String>.from(data['favoriteVolunteers'] ?? []);
    });
  }

  Future<void> _toggleFavorite(String volunteerId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    setState(() {
      if (_favoriteIds.contains(volunteerId)) {
        _favoriteIds.remove(volunteerId);
      } else {
        _favoriteIds.add(volunteerId);
      }
    });

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      {
        'favoriteVolunteers': _favoriteIds,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Stream<QuerySnapshot> _volunteersStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'volunteer')
        .snapshots();
  }

  Stream<double> _ratingStream(String volunteerId) {
    return FirebaseFirestore.instance
        .collection('volunteer_reviews')
        .where('volunteerId', isEqualTo: volunteerId)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) {
        return 0.0;
      }

      double total = 0;

      for (final doc in snap.docs) {
        final data = doc.data();

        total += (data['stars'] ?? 0).toDouble();
      }

      return total / snap.docs.length;
    });
  }

  double? _getDistanceKm(Map<String, dynamic> data) {
    final value =
        data['distanceKm'] ?? data['distance'] ?? data['distanceInKm'];

    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  double? _distanceLimit(String value) {
    switch (value) {
      case '1 km':
        return 1;
      case '5 km':
        return 5;
      case '10 km':
        return 10;
      case '20 km':
        return 20;
      default:
        return null;
    }
  }

  List<Map<String, dynamic>> _filterVolunteers(QuerySnapshot snapshot) {
    final volunteers = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;

      return {
        'id': doc.id,
        'name':
            data['name'] ?? data['fullName'] ?? data['username'] ?? 'Volunteer',
        'helpType':
            data['helpType'] ?? data['volunteerType'] ?? 'Daily Support',
        'gender': data['gender'] ?? 'Unknown',
        'isAvailable': data['isAvailable'] ?? true,
        'rating': (data['rating'] ?? 0).toDouble(),
        'photoUrl': data['photoUrl'] ?? '',
        'phone': data['phone'] ?? data['phoneNumber'] ?? '',
        'volunteerSpecialty': data['volunteerSpecialty'] ?? '',
        'volunteerSkill': data['volunteerSkill'] ?? '',
        'volunteerBio': data['volunteerBio'] ?? '',
        'volunteerWork': data['volunteerWork'] ?? '',
        'distanceKm':
            data['distanceKm'] ?? data['distance'] ?? data['distanceInKm'],
        'availableTimes': data['availableTimes'] ??
            data['availabilityTimes'] ??
            data['freeTimes'],
      };
    }).where((v) {
      final volunteerId = v['id'].toString();

      final name = v['name'].toString().toLowerCase();
      final helpType = v['helpType'].toString().toLowerCase();
      final specialty = v['volunteerSpecialty'].toString().toLowerCase();
      final skill = v['volunteerSkill'].toString().toLowerCase();
      final gender = v['gender'].toString().toLowerCase();

      final isAvailable = v['isAvailable'] == true;

      final matchesSearch = _searchText.isEmpty ||
          name.contains(_searchText) ||
          helpType.contains(_searchText) ||
          specialty.contains(_searchText) ||
          skill.contains(_searchText) ||
          gender.contains(_searchText);

      final matchesFavorite =
          !_showFavoritesOnly || _favoriteIds.contains(volunteerId);

      final matchesStatus = _selectedStatus == 'All' ||
          (_selectedStatus == 'Available' && isAvailable) ||
          (_selectedStatus == 'Busy' && !isAvailable);

      final selectedCategory = _selectedCategory.toLowerCase();

      final matchesCategory = _selectedCategory == 'All' ||
          helpType == selectedCategory ||
          helpType.contains(selectedCategory) ||
          specialty.contains(selectedCategory) ||
          skill.contains(selectedCategory);

      final distanceLimit = _distanceLimit(_selectedDistance);

      final volunteerDistance = _getDistanceKm(v);

      final matchesDistance = distanceLimit == null ||
          (volunteerDistance != null && volunteerDistance <= distanceLimit);

      return matchesSearch &&
          matchesFavorite &&
          matchesStatus &&
          matchesCategory &&
          matchesDistance;
    }).toList();

    volunteers.sort((a, b) {
      final aName = a['name'].toString().toLowerCase();

      final bName = b['name'].toString().toLowerCase();

      if (_selectedSort == 'Z-A') {
        return bName.compareTo(aName);
      }

      return aName.compareTo(bName);
    });

    return volunteers;
  }

  Future<void> _showFilterSheet() async {
    String tempSort = _selectedSort;
    String tempStatus = _selectedStatus;
    String tempCategory = _selectedCategory;
    String tempDistance = _selectedDistance;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Directionality(
          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 18,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: isArabic
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        tr('Filter Volunteers', 'فلترة المتطوعين'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF025590),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _filterTitle(tr('Sort', 'الترتيب')),
                      _filterChips(
                        options: _sortOptions,
                        selected: tempSort,
                        onSelected: (value) {
                          setModalState(() {
                            tempSort = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _filterTitle(tr('Status', 'الحالة')),
                      _filterChips(
                        options: _statusOptions,
                        selected: tempStatus,
                        onSelected: (value) {
                          setModalState(() {
                            tempStatus = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _filterTitle(tr('Category', 'التصنيف')),
                      _filterChips(
                        options: _categoryOptions,
                        selected: tempCategory,
                        onSelected: (value) {
                          setModalState(() {
                            tempCategory = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _filterTitle(tr('Distance', 'المسافة')),
                      _filterChips(
                        options: _distanceOptions,
                        selected: tempDistance,
                        onSelected: (value) {
                          setModalState(() {
                            tempDistance = value;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setModalState(() {
                                  tempSort = 'A-Z';
                                  tempStatus = 'All';
                                  tempCategory = 'All';
                                  tempDistance = 'All';
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black87,
                                side: const BorderSide(
                                  color: Color(0xFF87CEEB),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                minimumSize: const Size(0, 50),
                              ),
                              child: Text(tr('Reset', 'إعادة')),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedSort = tempSort;
                                  _selectedStatus = tempStatus;
                                  _selectedCategory = tempCategory;
                                  _selectedDistance = tempDistance;
                                });

                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF87CEEB),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                minimumSize: const Size(0, 50),
                              ),
                              child: Text(tr('Apply', 'تطبيق')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _filterTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        textAlign: isArabic ? TextAlign.right : TextAlign.left,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _filterChips({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((item) {
        final active = selected == item;

        return ChoiceChip(
          label: Text(
            optionText(item),
            overflow: TextOverflow.ellipsis,
          ),
          selected: active,
          selectedColor: const Color(0xFF87CEEB),
          backgroundColor: const Color(0xFFF4F4F4),
          labelStyle: TextStyle(
            color: active ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) {
            onSelected(item);
          },
        );
      }).toList(),
    );
  }

  Widget _buildSearchAndActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 56,
              ),
              decoration: BoxDecoration(
                color: fieldColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                textAlign: isArabic ? TextAlign.right : TextAlign.left,
                style: TextStyle(
                  color: textColor,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                  ),
                  suffixIcon: IconButton(
                    onPressed: _showFilterSheet,
                    icon: const Icon(
                      Icons.tune_rounded,
                    ),
                    tooltip: tr('Filter', 'فلتر'),
                  ),
                  hintText: tr('Search volunteer', 'ابحث عن متطوع'),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _showFavoritesOnly = !_showFavoritesOnly;
              });
            },
            child: Container(
              width: 54,
              height: 56,
              decoration: BoxDecoration(
                color: _showFavoritesOnly
                    ? Colors.red.withOpacity(0.14)
                    : fieldColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
                color: _showFavoritesOnly ? Colors.red : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterText() {
    final List<String> filters = [];

    if (_selectedSort != 'A-Z') {
      filters.add(optionText(_selectedSort));
    }

    if (_selectedStatus != 'All') {
      filters.add(optionText(_selectedStatus));
    }

    if (_selectedCategory != 'All') {
      filters.add(optionText(_selectedCategory));
    }

    if (_selectedDistance != 'All') {
      filters.add(_selectedDistance);
    }

    if (_showFavoritesOnly) {
      filters.add(tr('Favorites', 'المفضلة'));
    }

    if (filters.isEmpty) {
      return const SizedBox(height: 12);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
      child: Align(
        alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          filters.join(' • '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: subTextColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSmallScreen) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 130,
              width: double.infinity,
              color: const Color(0xFF87CEEB),
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
                  tr('Volunteer Help', 'مساعدة المتطوعين'),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 20 : 25,
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

  Widget _buildVolunteerCard(Map<String, dynamic> data) {
    final screenWidth = MediaQuery.of(context).size.width;

    final bool small = screenWidth < 380;

    final String volunteerId = data['id'].toString();

    final String name = data['name'].toString();

    final String helpType = data['helpType'].toString();

    final String gender = data['gender'].toString();

    final String specialty = data['volunteerSpecialty'].toString();

    final String skill = data['volunteerSkill'].toString();

    final bool isAvailable = data['isAvailable'] == true;

    final String photoUrl = data['photoUrl'].toString();

    final bool isFavorite = _favoriteIds.contains(volunteerId);

    final String mainSkill = specialty.trim().isNotEmpty
        ? specialty
        : skill.trim().isNotEmpty
            ? skill
            : helpTypeText(helpType);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        VoiceAccessibilityService.instance.stopAll();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VolunteerHelpInfoPage(
              volunteer: data,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(
          bottom: 16,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: small ? 12 : 14,
          vertical: small ? 12 : 14,
        ),
        decoration: BoxDecoration(
          color: cardBackgroundColor(isAvailable),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildVolunteerImage(
              photoUrl: photoUrl,
              gender: gender,
              small: small,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildVolunteerMiddleInfo(
                volunteerId: volunteerId,
                name: name,
                helpType: helpType,
                gender: gender,
                mainSkill: mainSkill,
                isFavorite: isFavorite,
                isAvailable: isAvailable,
                small: small,
              ),
            ),
            const SizedBox(width: 8),
            _buildVolunteerRightSide(
              isAvailable: isAvailable,
              small: small,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolunteerImage({
    required String photoUrl,
    required String gender,
    required bool small,
  }) {
    return CircleAvatar(
      radius: small ? 32 : 38,
      backgroundColor: Colors.white,
      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
      child: photoUrl.isEmpty
          ? Icon(
              Icons.person,
              size: small ? 38 : 44,
              color: Colors.grey,
            )
          : null,
    );
  }

  Widget _buildVolunteerMiddleInfo({
    required String volunteerId,
    required String name,
    required String helpType,
    required String gender,
    required String mainSkill,
    required bool isFavorite,
    required bool isAvailable,
    required bool small,
  }) {
    return Column(
      crossAxisAlignment:
          isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildVolunteerNameAndGender(
          name: name,
          gender: gender,
          isAvailable: isAvailable,
          small: small,
        ),
        const SizedBox(height: 5),
        _buildVolunteerSkillText(
          mainSkill: mainSkill,
          small: small,
        ),
        const SizedBox(height: 5),
        _buildVolunteerGenderText(
          gender: gender,
          small: small,
        ),
        const SizedBox(height: 10),
        _buildRatingAndFavoriteRow(
          volunteerId: volunteerId,
          isFavorite: isFavorite,
          small: small,
        ),
      ],
    );
  }

  Widget _buildVolunteerNameAndGender({
    required String name,
    required String gender,
    required bool isAvailable,
    required bool small,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: small ? 18 : 21,
              fontWeight: FontWeight.bold,
              color: cardTitleColor(isAvailable),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          genderIcon(gender),
          color: genderColor(gender),
          size: small ? 20 : 22,
        ),
      ],
    );
  }

  Widget _buildVolunteerSkillText({
    required String mainSkill,
    required bool small,
  }) {
    return Text(
      mainSkill,
      textAlign: isArabic ? TextAlign.right : TextAlign.left,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: subTextColor,
        fontSize: small ? 13 : 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildVolunteerGenderText({
    required String gender,
    required bool small,
  }) {
    return Text(
      genderText(gender),
      textAlign: isArabic ? TextAlign.right : TextAlign.left,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: subTextColor,
        fontSize: small ? 13 : 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildRatingAndFavoriteRow({
    required String volunteerId,
    required bool isFavorite,
    required bool small,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRatingBadge(
          volunteerId: volunteerId,
          small: small,
        ),
        const SizedBox(width: 12),
        _buildFavoriteButton(
          volunteerId: volunteerId,
          isFavorite: isFavorite,
          small: small,
        ),
      ],
    );
  }

  Widget _buildRatingBadge({
    required String volunteerId,
    required bool small,
  }) {
    return StreamBuilder<double>(
      stream: _ratingStream(volunteerId),
      builder: (context, snap) {
        final rating = snap.data ?? 0.0;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: small ? 9 : 10,
            vertical: small ? 5 : 6,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.star,
                color: Colors.amber,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                rating.toStringAsFixed(1),
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: small ? 13 : 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFavoriteButton({
    required String volunteerId,
    required bool isFavorite,
    required bool small,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        _toggleFavorite(volunteerId);
      },
      child: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        color: isFavorite ? Colors.red : Colors.grey,
        size: small ? 26 : 28,
      ),
    );
  }

  Widget _buildVolunteerRightSide({
    required bool isAvailable,
    required bool small,
  }) {
    return SizedBox(
      width: small ? 94 : 110,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            isArabic ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          _buildStatusBadge(
            isAvailable: isAvailable,
            small: small,
          ),
          const SizedBox(height: 36),
          _buildArrowIcon(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge({
    required bool isAvailable,
    required bool small,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 10 : 14,
        vertical: small ? 7 : 8,
      ),
      decoration: BoxDecoration(
        color: statusBackgroundColor(isAvailable),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        availabilityText(isAvailable),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: statusTextColor(isAvailable),
          fontSize: small ? 12 : 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildArrowIcon() {
    return Icon(
      isArabic ? Icons.arrow_back_ios_new : Icons.arrow_forward_ios,
      size: 18,
      color: Colors.black87,
    );
  }

  void _goToPage(int index) {
    VoiceAccessibilityService.instance.stopAll();

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const DashboardPage(),
        ),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const ProfilePage(),
        ),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const SettingsPage(),
        ),
      );
    }
  }

  Widget _bottomItem(IconData icon, String label, int index) {
    return Flexible(
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF87CEEB),
          borderRadius: BorderRadius.circular(30),
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

  Future<void> _startVoiceAccessibilityAssistant() async {
    if (!mounted) return;

    await VoiceAccessibilityService.instance.stopAll();

    setState(() {
      _isSpeaking = true;
    });

    await VoiceAccessibilityService.instance.readPageAndListen(
      context: context,
      pageText: tr(
        'Volunteer Help screen with search and filter options to find volunteers. Filter options include sort, status, category, and distance. You can save volunteers to favorites for quick access later and request help from available volunteers. Home, profile, and settings options are available.',
        'صفحة مساعدة المتطوعين تحتوي على خيارات البحث والفلترة للعثور على المتطوعين. تشمل خيارات الفلترة الترتيب، والحالة، والتصنيف، والمسافة. يمكنك حفظ المتطوعين في المفضلة للوصول السريع لاحقًا وطلب المساعدة من المتطوعين المتاحين. تتوفر أيضًا خيارات الرئيسية والملف الشخصي والإعدادات.',
      ),
      routes: {
        'dashboard': (context) => const DashboardPage(),
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
                  ? const Color(0xFF87CEEB) // Blue = reading
                  : const Color(0xFFFF5A5F), // Red = silent
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2E000000),
                  blurRadius: 14,
                  offset: Offset(0, 6),
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

  void _goBack() {
    VoiceAccessibilityService.instance.stopAll();

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const DashboardPage(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final isSmallScreen = screenWidth < 380;

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
              backgroundColor: backgroundColor,
              body: Stack(
                children: [
                  SafeArea(
                    child: Column(
                      children: [
                        _buildHeader(isSmallScreen),
                        _buildSearchAndActions(),
                        _buildActiveFilterText(),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: _volunteersStream(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF87CEEB),
                                  ),
                                );
                              }

                              final volunteers =
                                  _filterVolunteers(snapshot.data!);

                              if (volunteers.isEmpty) {
                                return Center(
                                  child: Text(
                                    tr('No volunteers found',
                                        'لا يوجد متطوعون'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }

                              return ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 8, 20, 32),
                                itemCount: volunteers.length,
                                itemBuilder: (context, index) {
                                  return _buildVolunteerCard(volunteers[index]);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  _voiceControlButton(),
                ],
              ),
              bottomNavigationBar: _buildBottomNavigation(),
            ),
          ),
        );
      },
    );
  }
}
