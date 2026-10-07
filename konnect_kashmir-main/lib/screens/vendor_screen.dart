import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/category_meta.dart';

// ── Brand accent — consistent across light & dark ──────────────────────────
const Color _kTeal   = Color(0xFF6BC4B2);
const Color _kTealDk = Color(0xFF2F6F62);

class _ServiceOption {
  final String name;
  final IconData icon;
  final Color iconColor;
  final String slug;

  const _ServiceOption({
    required this.name,
    required this.icon,
    required this.iconColor,
    required this.slug,
  });
}

class ListBusinessScreen extends StatefulWidget {
  final Map<String, dynamic>? existingVendor;

  const ListBusinessScreen({super.key, this.existingVendor});

  @override
  State<ListBusinessScreen> createState() => _ListBusinessScreenState();
}

class _ListBusinessScreenState extends State<ListBusinessScreen> {
  static const String _supabaseUrl     = 'https://fmmpsqnpezjofsluirrv.supabase.co';
  static const String _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZtbXBzcW5wZXpqb2ZzbHVpcnJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2MzIyNTgsImV4cCI6MjA4NTIwODI1OH0'
      '.6FCU_FLaHsKsE7G50A7-_zYf46GZiKpecg4l_de3tn4';

  final _formKey                                              = GlobalKey<FormState>();
  final TextEditingController _businessNameController        = TextEditingController();
  final TextEditingController _businessDescriptionController = TextEditingController();
  final TextEditingController _phoneController               = TextEditingController();
  final TextEditingController _whatsappController            = TextEditingController();
  final TextEditingController _emailController               = TextEditingController();
  final TextEditingController _addressController             = TextEditingController();
  final TextEditingController _searchController              = TextEditingController();

  List<String> _selectedServiceTypes = [];
  bool   _serviceDropdownOpen = false;
  bool   _serviceTypeError    = false;
  String _searchQuery         = '';

  String? _selectedDistrict;
  String? _selectedLocality;
  bool _homeServiceAvailable = false;
  bool _acceptOnlinePayment  = false;
  bool _isSubmitting         = false;

  bool get _isEditing => widget.existingVendor != null;

  // ── CHANGE 1: Responsive helpers ─────────────────────────────────────────
  // All sizes are derived from screen width so the layout adapts to any device.
  double get _sw => MediaQuery.of(context).size.width;
  double get _sh => MediaQuery.of(context).size.height;

  /// Returns [fraction * screenWidth] clamped between [min] and [max].
  double _rs(double fraction, {double min = 0, double max = double.infinity}) =>
      (_sw * fraction).clamp(min, max);

  // ── CHANGE 2: Safe-area top padding ──────────────────────────────────────
  double get _topPad => MediaQuery.of(context).padding.top;

  // ── Theme-adaptive logo ───────────────────────────────────────────────────
  Widget _adaptiveLogo({double? height}) {
    // ── CHANGE 3: Logo height scales with screen width ───────────────────────
    final h = height ?? _rs(0.12, min: 32, max: 56);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1,  0,  0, 0, 255,
          0, -1,  0, 0, 255,
          0,  0, -1, 0, 255,
          0,  0,  0, 1,   0,
        ]),
        child: Image.asset('assets/images/konnectkashmir.png', height: h),
      );
    } else {
      return Image.asset('assets/images/konnectkashmir.png', height: h);
    }
  }

  // Same categories as the customer screen: built-in list first, replaced by
  // the live service_categories from the API once loaded.
  List<_ServiceOption> _serviceOptions = _optionsFrom(CategoryMeta.allCategories);

  static List<_ServiceOption> _optionsFrom(List<dynamic> source) {
    final seen = <String>{};
    final out = <_ServiceOption>[];
    for (final e in source) {
      final slug = (e['slug'] ?? e['id'] ?? '').toString();
      final name = (e['name'] ?? '').toString();
      if (slug.isEmpty || name.isEmpty || !seen.add(name)) continue;
      final meta = CategoryMeta.of(slug);
      out.add(_ServiceOption(
          name: name, icon: meta.icon, iconColor: meta.color, slug: slug));
    }
    return out;
  }

  Future<void> _loadServiceOptions() async {
    try {
      final auth = context.read<AuthProvider>();
      final data = await ApiService(token: auth.accessToken, userId: auth.userId)
          .getServiceCategories();
      final opts = _optionsFrom(data);
      if (!mounted || opts.isEmpty) return;
      setState(() {
        // Keep selections valid when names differ between the two lists.
        final selectedSlugs =
            _selectedServiceTypes.map(_slugForService).toList();
        _serviceOptions = opts;
        _selectedServiceTypes = [
          for (final s in selectedSlugs)
            ...opts.where((o) => o.slug == s).take(1).map((o) => o.name),
        ];
      });
    } catch (_) {}
  }

  final Map<String, List<String>> _districtLocalities = {
    'Srinagar': [
      'Batamaloo', 'Bemina', 'Channapora', 'Dalgate', 'Harwan', 'Hawal',
      'Hyderpora', 'Khanyar', 'Kralgund', 'Lal Chowk', 'Rajbagh',
      'Jawahar Nagar', 'Nishat', 'Hazratbal', 'Soura', 'Baghat',
      'Panthachowk', 'Nowshera', 'Other(Srinagar)', 'Rainawari', 'Shalimar',
    ],
    'Baramulla': [
      'Baramulla Town', 'Sopore', 'Uri', 'Pattan', 'Tangmarg', 'Gulmarg',
      'Boniyar', 'Kreeri', 'Kunzer', 'Kawarhama', 'Narwav', 'Singh',
      'Khoie', 'Dangerpora', 'Dangiwacha', 'Watergam', 'Rohama',
      'Zaingeer', 'Wagoora',
    ],
    'Anantnag': [
      'Anantnag Town', 'Bijbehara', 'Pahalgam', 'Mattan', 'Shangus',
      'Kokernag', 'Dooru', 'Verinag', 'Anantnag East Mattan',
      'ShahbadBalla', 'Qazigund', 'Saller', 'Srigufwara', 'Larnoo',
    ],
    'Pulwama': [
      'Pulwama Town', 'Pampore', 'Awantipora', 'Tral', 'Rajpora',
      'Kakapora', 'Shahoora', 'Aripal',
    ],
    'Budgam': [
      'Budgam Town', 'Magam', 'Narbal', 'Beerwah', 'Chadoora',
      'Khansahib', 'Charar-i-Sharief', 'Khag', 'B.K.Pora',
    ],
    'Bandipora': ['Bandipora', 'Sumbal Sonawari', 'Ajas', 'Hajin', 'Aloosa', 'Gurez', 'Tulail'],
    'Kulgam':    ['Kulgam', 'D.H.Pora', 'Devsar', 'Frisal', 'Pahloo', 'Yaripora', 'Qaimoh'],
    'Kupwara': [
      'Kupwara', 'Handwara', 'Karnah', 'Keran', 'Kralpora', 'Trehgam',
      'Machil', 'Dragmulla', 'Ramhal', 'Qaziabad', 'Langate',
      'Zachaldara', 'Lolab', 'Lalpora', 'Villgam', 'Lalamabad',
    ],
    'Ganderbal': ['Ganderbal', 'Kangan', 'Lar', 'Tullamulla', 'Wakura', 'Gund'],
  };

  @override
  void initState() {
    super.initState();
    _loadServiceOptions();
    if (_isEditing) {
      final v = widget.existingVendor!;
      _businessNameController.text        = v['business_name']    as String? ?? '';
      _businessDescriptionController.text = v['description']       as String? ?? '';
      _phoneController.text               = v['phone']             as String? ?? '';
      _whatsappController.text            = v['whatsapp_number']   as String? ?? '';
      _emailController.text               = v['email']             as String? ?? '';
      _addressController.text             = v['address']           as String? ?? '';
      _homeServiceAvailable = v['provides_home_service']  as bool? ?? false;
      _acceptOnlinePayment  = v['accepts_online_payment'] as bool? ?? false;

      final slug = v['service_type'] as String?;
      if (slug != null) {
        final match = _serviceOptions.where((o) => o.slug == slug);
        if (match.isNotEmpty) _selectedServiceTypes = [match.first.name];
      }

      final localityName = (v['localities'] as Map?)?['name'] as String?;
      if (localityName != null) {
        for (final entry in _districtLocalities.entries) {
          if (entry.value.contains(localityName)) {
            _selectedDistrict = entry.key;
            _selectedLocality = localityName;
            break;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessDescriptionController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<_ServiceOption> get _filteredOptions {
    if (_searchQuery.isEmpty) return _serviceOptions;
    return _serviceOptions
        .where((o) => o.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  String _slugForService(String name) =>
      _serviceOptions.firstWhere((o) => o.name == name, orElse: () => _serviceOptions.last).slug;

  // ── Theme helpers ─────────────────────────────────────────────────────────
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  ColorScheme get _cs => Theme.of(context).colorScheme;

  Color get _cardFill       => _isDark ? Colors.black.withOpacity(0.25) : _cs.surface;
  Color get _inputFill      => _cs.onSurface.withOpacity(0.08);
  Color get _borderColor    => _cs.onSurface.withOpacity(0.08);
  Color get _subtleBorder   => _cs.outline.withOpacity(_isDark ? 0.12 : 0.20);
  Color get _onSurface      => _cs.onSurface;
  Color get _onSurfaceMuted => _cs.onSurface.withOpacity(0.55);

  @override
  Widget build(BuildContext context) {

    // ── CHANGE 4: Horizontal padding scales with screen width ────────────────
    // Was a fixed 24 px on every screen. Now it breathes on tablets and stays
    // comfortable on 320 px phones.
    final double hPad = _rs(0.06, min: 16, max: 32);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              // ── CHANGE 5: AppBar top padding from safe-area, not hardcoded ──
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: false,
                toolbarHeight: kToolbarHeight + (_topPad > 0 ? 0 : 8),
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: _onSurface),
                  onPressed: () => Navigator.pop(context),
                ),
                title: _adaptiveLogo(),
              ),
              SliverToBoxAdapter(
                child: Divider(color: _subtleBorder, height: 1),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  // ── CHANGE 6: Vertical top padding proportional to screen height ─
                  padding: EdgeInsets.symmetric(
                    horizontal: hPad,
                    vertical: _sh * 0.04,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── CHANGE 7: Title font size scales; FittedBox prevents
                        //    overflow on 320 px wide devices ───────────────────
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _isEditing ? 'Edit Business' : 'List Your Business',
                            style: TextStyle(
                              color: _onSurface,
                              fontSize: _rs(0.08, min: 22, max: 36),
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isEditing
                              ? 'Update your business information'
                              : 'Get your business listed on KonnectKashmir',
                          style: TextStyle(
                            color: _onSurfaceMuted,
                            fontSize: _rs(0.04, min: 13, max: 17),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        _buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Business Details header ──────────────────
                              Row(children: [
                                const Icon(Icons.business, color: _kTeal),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Business Details',
                                    style: TextStyle(
                                      color: _onSurface,
                                      fontSize: _rs(0.05, min: 16, max: 22),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ]),
                              Divider(color: _subtleBorder, height: 20),
                              _buildLabel('Business Name *'),
                              const SizedBox(height: 6),
                              _buildTextField(
                                controller: _businessNameController,
                                hintText: "e.g., Ahmed's Plumbing Service",
                                isRequired: true,
                              ),
                              const SizedBox(height: 14),
                              _buildLabel('Service Categories * (select up to 3)'),
                              const SizedBox(height: 6),
                              _buildServiceCategorySelector(),
                              const SizedBox(height: 14),
                              _buildLabel('District *'),
                              const SizedBox(height: 6),
                              _buildDropdown(
                                value: _selectedDistrict,
                                hint: 'Select district',
                                items: _districtLocalities.keys.toList(),
                                onChanged: (value) => setState(() {
                                  _selectedDistrict = value;
                                  _selectedLocality = null;
                                }),
                                isRequired: true,
                              ),
                              const SizedBox(height: 14),
                              _buildLabel('Locality *'),
                              const SizedBox(height: 6),
                              _buildDropdown(
                                value: _selectedLocality,
                                hint: _selectedDistrict == null
                                    ? 'Select district first'
                                    : 'Select locality',
                                items: _selectedDistrict != null
                                    ? _districtLocalities[_selectedDistrict]!
                                    : [],
                                onChanged: _selectedDistrict != null
                                    ? (value) => setState(() => _selectedLocality = value)
                                    : null,
                                isRequired: true,
                              ),
                              const SizedBox(height: 14),
                              _buildLabel('Business Description (optional)'),
                              const SizedBox(height: 6),
                              _buildTextField(
                                controller: _businessDescriptionController,
                                hintText: 'Tell customers about your services...',
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Contact Info header ──────────────────────
                              Row(children: [
                                const Icon(Icons.phone, color: _kTeal),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Contact Info',
                                    style: TextStyle(
                                      color: _onSurface,
                                      fontSize: _rs(0.05, min: 16, max: 22),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ]),
                              Divider(color: _subtleBorder, height: 20),

                              _buildLabel('Business Phone Number *'),
                              const SizedBox(height: 6),
                              _buildPhoneRow(
                                controller: _phoneController,
                                hintText: '9876543210',
                                isRequired: true,
                              ),
                              const SizedBox(height: 14),
                              Row(children: [
                                Icon(Icons.chat_bubble_outline, color: _onSurfaceMuted),
                                const SizedBox(width: 8),
                                Text('WhatsApp', style: TextStyle(color: _onSurfaceMuted)),
                              ]),
                              const SizedBox(height: 6),
                              _buildPhoneRow(
                                controller: _whatsappController,
                                hintText: 'Same or different',
                              ),
                              const SizedBox(height: 14),
                              Row(children: [
                                Icon(Icons.email_outlined, color: _onSurfaceMuted),
                                const SizedBox(width: 8),
                                Text('Email', style: TextStyle(color: _onSurfaceMuted)),
                              ]),
                              const SizedBox(height: 6),
                              _buildTextField(
                                controller: _emailController,
                                hintText: 'business@email.com',
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 14),
                              Row(children: [
                                Icon(Icons.location_on_outlined, color: _onSurfaceMuted),
                                const SizedBox(width: 8),
                                Text('Address', style: TextStyle(color: _onSurfaceMuted)),
                              ]),
                              const SizedBox(height: 6),
                              _buildTextField(
                                controller: _addressController,
                                hintText: 'Shop/Office address',
                              ),
                              const SizedBox(height: 14),
                              _buildSwitchTile(
                                icon: Icons.home_outlined,
                                label: 'Home Service Available',
                                value: _homeServiceAvailable,
                                onChanged: (v) => setState(() => _homeServiceAvailable = v),
                              ),
                              const SizedBox(height: 10),
                              _buildSwitchTile(
                                icon: Icons.payment_outlined,
                                label: 'Accept Online Payment',
                                value: _acceptOnlinePayment,
                                onChanged: (v) => setState(() => _acceptOnlinePayment = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                              if (!_isEditing) ...[
                                Row(children: [
                                  Icon(Icons.hourglass_empty, color: Colors.orange[300]),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Your listing will be reviewed within 24-48 hours',
                                      style: TextStyle(
                                        color: _onSurfaceMuted,
                                        fontSize: _rs(0.035, min: 12, max: 15),
                                      ),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 12),
                              ],

                              // ── CHANGE 9: Action buttons use LayoutBuilder
                              //    to stack vertically on screens < 360 px ────
                              LayoutBuilder(builder: (ctx, constraints) {
                                final bool narrow = constraints.maxWidth < 300;
                                final buttonStyle_outlined = OutlinedButton.styleFrom(
                                  foregroundColor: _onSurface,
                                  side: BorderSide(color: _borderColor),
                                  padding: EdgeInsets.symmetric(
                                    vertical: _rs(0.04, min: 14, max: 18),
                                  ),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                );
                                final buttonStyle_filled = ElevatedButton.styleFrom(
                                  backgroundColor: _isDark
                                      ? const Color(0xFF0E3D2E)
                                      : _cs.primary,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    vertical: _rs(0.04, min: 14, max: 18),
                                  ),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  disabledBackgroundColor:
                                  _cs.onSurface.withOpacity(0.12),
                                );

                                final cancelBtn = OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: buttonStyle_outlined,
                                  child: Text('Cancel',
                                      style: TextStyle(
                                          fontSize: _rs(0.04, min: 13, max: 17))),
                                );
                                final submitBtn = ElevatedButton(
                                  onPressed: _isSubmitting
                                      ? null
                                      : () {
                                    if (_formKey.currentState!.validate()) {
                                      _submitForm();
                                    }
                                  },
                                  style: buttonStyle_filled,
                                  child: _isSubmitting
                                      ? const SizedBox(
                                    height: 20, width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                      : Text(
                                    _isEditing ? 'Save Changes' : 'Submit',
                                    style: TextStyle(
                                        fontSize: _rs(0.04, min: 13, max: 17)),
                                  ),
                                );

                                if (narrow) {
                                  // Stack buttons vertically on very small screens
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      submitBtn,
                                      const SizedBox(height: 12),
                                      cancelBtn,
                                    ],
                                  );
                                }
                                return Row(children: [
                                  Expanded(child: cancelBtn),
                                  const SizedBox(width: 16),
                                  Expanded(child: submitBtn),
                                ]);
                              }),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Reusable phone row (prefix + field) ──────────────────────────────────
  Widget _buildPhoneRow({
    required TextEditingController controller,
    required String hintText,
    bool isRequired = false,
  }) {
    return Row(children: [
      // ── CHANGE 10: +91 prefix box no longer overflows on small screens ──
      Container(
        padding: EdgeInsets.symmetric(
          horizontal: _rs(0.04, min: 12, max: 18),
          vertical: _rs(0.04, min: 14, max: 18),
        ),
        decoration: BoxDecoration(
          color: _inputFill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderColor),
        ),
        child: Text('+91', style: TextStyle(color: _onSurfaceMuted)),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _buildTextField(
          controller: controller,
          hintText: hintText,
          keyboardType: TextInputType.phone,
          isRequired: isRequired,
        ),
      ),
    ]);
  }

  // ── Service category multi-selector ──────────────────────────────────────
  Widget _buildServiceCategorySelector() {
    final openBg   = _isDark ? const Color(0xFFA0522D).withOpacity(0.75) : _cs.secondaryContainer;
    final openBord = _isDark ? const Color(0xFFA0522D) : _cs.secondary;
    final listBg   = _isDark ? const Color(0xFF1A1A1A) : _cs.surface;
    final selBg    = _isDark
        ? const Color(0xFF8B1A1A).withOpacity(0.85)
        : _cs.primaryContainer.withOpacity(0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() {
            _serviceDropdownOpen = !_serviceDropdownOpen;
            if (!_serviceDropdownOpen) {
              _searchController.clear();
              _searchQuery = '';
            }
            _serviceTypeError = false;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: _serviceDropdownOpen ? openBg : _inputFill,
              borderRadius: _serviceDropdownOpen
                  ? const BorderRadius.vertical(top: Radius.circular(10))
                  : BorderRadius.circular(10),
              border: Border.all(
                color: _serviceTypeError
                    ? Colors.red
                    : _serviceDropdownOpen
                    ? openBord
                    : _borderColor,
                width: _serviceTypeError ? 1.5 : 1,
              ),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  _selectedServiceTypes.isEmpty
                      ? 'Select up to 3 categories'
                      : _selectedServiceTypes.join(', '),
                  style: TextStyle(
                    color: _selectedServiceTypes.isEmpty ? _onSurfaceMuted : _onSurface,
                    fontSize: _rs(0.037, min: 13, max: 16),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                _serviceDropdownOpen
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: _onSurfaceMuted,
              ),
            ]),
          ),
        ),
        if (_serviceDropdownOpen)
          Container(
            decoration: BoxDecoration(
              color: listBg,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
              border: Border.all(color: _subtleBorder),
            ),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: _onSurface, fontSize: 14),
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search categories...',
                    hintStyle: TextStyle(color: _onSurfaceMuted, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: _onSurfaceMuted, size: 20),
                    filled: true,
                    fillColor: _inputFill,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Divider(color: _subtleBorder, height: 1),
              // ── CHANGE 11: Dropdown list height scales with screen height ─
              // Was a fixed 260 px — on a 568 px iPhone SE that consumed 46 %
              // of the visible area. Now it adapts between 180 and 300 px.
              SizedBox(
                height: _rs(0.35, min: 180, max: 300),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _filteredOptions.length,
                  separatorBuilder: (_, __) => Divider(color: _subtleBorder, height: 1),
                  itemBuilder: (context, index) {
                    final option     = _filteredOptions[index];
                    final isSelected = _selectedServiceTypes.contains(option.name);
                    final isDisabled = !isSelected && _selectedServiceTypes.length >= 3;

                    return InkWell(
                      onTap: isDisabled
                          ? null
                          : () => setState(() {
                        if (isSelected) {
                          _selectedServiceTypes.remove(option.name);
                        } else {
                          _selectedServiceTypes.add(option.name);
                          // Picked a category: close the dropdown.
                          _serviceDropdownOpen = false;
                          _searchController.clear();
                          _searchQuery = '';
                        }
                      }),
                      child: Container(
                        color: isSelected ? selBg : Colors.transparent,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: _rs(0.035, min: 11, max: 16),
                        ),
                        child: Row(children: [
                          Container(
                            width: 22, height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? _onSurface
                                    : isDisabled
                                    ? _onSurface.withOpacity(0.25)
                                    : _onSurface.withOpacity(0.5),
                                width: 1.5,
                              ),
                            ),
                            child: isSelected
                                ? Center(
                              child: CircleAvatar(
                                radius: 5,
                                backgroundColor: _onSurface,
                              ),
                            )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            option.icon,
                            color: isDisabled
                                ? _onSurface.withOpacity(0.25)
                                : option.iconColor,
                            size: _rs(0.05, min: 16, max: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option.name,
                              style: TextStyle(
                                color: isDisabled
                                    ? _onSurface.withOpacity(0.35)
                                    : _onSurface,
                                fontSize: _rs(0.037, min: 13, max: 16),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),
        const SizedBox(height: 6),
        Text(
          '${_selectedServiceTypes.length}/3 categories selected',
          style: TextStyle(
            color: _serviceTypeError ? Colors.red : _onSurfaceMuted,
            fontSize: 12,
          ),
        ),
        if (_serviceTypeError)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text('Please select at least one service',
                style: TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ],
    );
  }

  // ── Reusable builders ─────────────────────────────────────────────────────
  Widget _buildCard({required Widget child}) {
    // ── CHANGE 12: Card padding is proportional, not a fixed 20 px ──────────
    return Container(
      padding: EdgeInsets.all(_rs(0.05, min: 14, max: 24)),
      decoration: BoxDecoration(
        color: _cardFill.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _subtleBorder),
      ),
      child: child,
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: _onSurface,
        fontSize: _rs(0.035, min: 12, max: 15),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool isRequired = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: _onSurface, fontSize: _rs(0.038, min: 13, max: 16)),
      validator: isRequired
          ? (value) {
        if (value == null || value.trim().isEmpty) return 'This field is required';
        return null;
      }
          : null,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: _onSurfaceMuted,
          fontSize: _rs(0.038, min: 13, max: 16),
        ),
        filled: true,
        fillColor: _inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kTeal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: _rs(0.04, min: 12, max: 18),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required void Function(String?)? onChanged,
    bool isRequired = false,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(hint,
          style: TextStyle(
              color: _onSurfaceMuted,
              fontSize: _rs(0.038, min: 13, max: 16))),
      validator: isRequired
          ? (value) {
        if (value == null || value.isEmpty) return 'Please select an option';
        return null;
      }
          : null,
      dropdownColor: _isDark ? const Color(0xFF1E2E2E) : _cs.surface,
      style: TextStyle(
          color: _onSurface,
          fontSize: _rs(0.038, min: 13, max: 16)),
      icon: Icon(Icons.keyboard_arrow_down, color: _onSurfaceMuted),
      decoration: InputDecoration(
        filled: true,
        fillColor: _inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kTeal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: _rs(0.04, min: 12, max: 18),
        ),
      ),
      items: items
          .map((item) => DropdownMenuItem(
          value: item,
          child: Text(item,
              style: TextStyle(fontSize: _rs(0.038, min: 13, max: 16)))))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String label,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return Row(children: [
      Icon(icon, color: _onSurfaceMuted),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            color: _onSurface,
            fontSize: _rs(0.04, min: 13, max: 17),
          ),
        ),
      ),
      Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: _kTeal,
        activeTrackColor: _kTealDk,
        inactiveThumbColor: _onSurfaceMuted,
        inactiveTrackColor: _onSurface.withOpacity(0.15),
      ),
    ]);
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  void _submitForm() async {
    if (_selectedServiceTypes.isEmpty) {
      setState(() => _serviceTypeError = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select at least one service type'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ));
      return;
    }

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill in all required fields'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token  = context.read<AuthProvider>().accessToken;
      final userId = context.read<AuthProvider>().user?.id;

      final headers = {
        'Content-Type':  'application/json',
        'apikey':        _supabaseAnonKey,
        'Authorization': 'Bearer ${token ?? _supabaseAnonKey}',
        'Prefer':        'return=representation',
      };

      // Resolve locality_id
      String? localityId;
      if (_selectedLocality != null) {
        final res = await http.get(
          Uri.parse('$_supabaseUrl/rest/v1/localities'
              '?name=eq.${Uri.encodeComponent(_selectedLocality!)}'
              '&select=id&limit=1'),
          headers: headers,
        );
        if (res.statusCode == 200) {
          final rows = jsonDecode(res.body) as List<dynamic>;
          if (rows.isNotEmpty) localityId = rows.first['id'] as String?;
        }
      }

      final primarySlug = _slugForService(_selectedServiceTypes.first);

      final vendorBody = {
        'business_name':          _businessNameController.text.trim(),
        'service_type':           primarySlug,
        'locality_id':            localityId,
        'description':            _businessDescriptionController.text.trim(),
        'phone':                  _phoneController.text.trim(),
        'whatsapp_number':        _whatsappController.text.trim().isEmpty
            ? _phoneController.text.trim()
            : _whatsappController.text.trim(),
        'email':                  _emailController.text.trim(),
        'address':                _addressController.text.trim(),
        'provides_home_service':  _homeServiceAvailable,
        'accepts_online_payment': _acceptOnlinePayment,
      };

      if (_isEditing) {
        final vendorId = widget.existingVendor!['id'].toString();
        final patchRes = await http.patch(
          Uri.parse('$_supabaseUrl/rest/v1/vendors?id=eq.$vendorId'),
          headers: headers,
          body: jsonEncode(vendorBody),
        );
        if (patchRes.statusCode != 200 && patchRes.statusCode != 204) {
          final err = jsonDecode(patchRes.body);
          setState(() => _isSubmitting = false);
          _showErrorDialog(err['message'] ?? 'Failed to update business');
          return;
        }

        await http.delete(
          Uri.parse('$_supabaseUrl/rest/v1/vendor_categories?vendor_id=eq.$vendorId'),
          headers: headers,
        );
        await http.post(
          Uri.parse('$_supabaseUrl/rest/v1/vendor_categories'),
          headers: headers,
          body: jsonEncode(_selectedServiceTypes
              .map((n) => {'vendor_id': vendorId, 'category_slug': _slugForService(n)})
              .toList()),
        );

        setState(() => _isSubmitting = false);
        _showSuccessDialog(isEdit: true);
      } else {
        final newBody = {
          ...vendorBody,
          'is_approved': false,
          'is_verified': false,
          if (userId != null) 'user_id': userId,
        };

        final vendorRes = await http.post(
          Uri.parse('$_supabaseUrl/rest/v1/vendors'),
          headers: headers,
          body: jsonEncode(newBody),
        );
        if (vendorRes.statusCode != 200 && vendorRes.statusCode != 201) {
          final err = jsonDecode(vendorRes.body);
          setState(() => _isSubmitting = false);
          _showErrorDialog(err['message'] ?? 'Failed to submit business');
          return;
        }

        final vendorId =
        ((jsonDecode(vendorRes.body) as List<dynamic>).first as Map<String, dynamic>)['id']
        as String;

        await http.post(
          Uri.parse('$_supabaseUrl/rest/v1/vendor_categories'),
          headers: headers,
          body: jsonEncode(_selectedServiceTypes
              .map((n) => {'vendor_id': vendorId, 'category_slug': _slugForService(n)})
              .toList()),
        );

        setState(() => _isSubmitting = false);
        debugPrint('Vendor created: $vendorId');
        _showSuccessDialog(isEdit: false);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showErrorDialog('Network error. Please check your connection.');
      debugPrint('Error submitting vendor: $e');
    }
  }

  void _showSuccessDialog({bool isEdit = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Theme.of(ctx).colorScheme.outline.withOpacity(0.2)),
        ),
        title: Text('Success',
            style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurface,
                fontWeight: FontWeight.bold)),
        content: Text(
          isEdit
              ? 'Your business has been updated successfully!'
              : 'Your business listing has been submitted for review!',
          style: TextStyle(
              color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('OK', style: TextStyle(color: _kTeal)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Theme.of(ctx).colorScheme.outline.withOpacity(0.2)),
        ),
        title: const Text('Error',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(message,
            style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: _kTeal)),
          ),
        ],
      ),
    );
  }
}