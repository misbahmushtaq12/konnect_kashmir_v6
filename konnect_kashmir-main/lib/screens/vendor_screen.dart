import 'dart:convert';

import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../l10n/category_names.dart';
import '../widgets/app_snack.dart';
import '../services/shared_http.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
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
  bool _whatsappSame = false; // WhatsApp uses the business number

  /// The phone number this account signed in with (verified by OTP), as the 10
  /// digits used everywhere else. Null if the session does not have it.
  String? get _verifiedPhone {
    final raw = context.read<AuthProvider>().user?.phoneNumber ?? '';
    final d = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length < 10) return null;
    return d.substring(d.length - 10);
  }

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
        child: Image.asset('assets/images/konnectkashmir.png', cacheHeight: 384, height: h),
      );
    } else {
      return Image.asset('assets/images/konnectkashmir.png', cacheHeight: 384, height: h);
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
      final meta = CategoryMeta.of(
        slug,
        name: name,
        iconName: e['icon']?.toString() ?? e['icon_name']?.toString(),
        colorHex: e['color']?.toString() ?? e['color_hex']?.toString(),
      );
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
    if (!_isEditing) _phoneController.text = _verifiedPhone ?? '';
    if (_isEditing) {
      final v = widget.existingVendor!;
      _businessNameController.text        = v['business_name']    as String? ?? '';
      _businessDescriptionController.text = v['description']       as String? ?? '';
      _phoneController.text               = v['phone']             as String? ?? '';
      if (_phoneController.text.trim().isEmpty) {
        _phoneController.text = _verifiedPhone ?? '';
      }
      _whatsappController.text            = v['whatsapp_number']   as String? ?? '';
      _whatsappSame = _whatsappController.text.trim().isNotEmpty &&
          _whatsappController.text.trim() == _phoneController.text.trim();
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
                toolbarHeight: 72,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: _onSurface),
                  onPressed: () => Navigator.pop(context),
                ),
                title: _adaptiveLogo(height: 56),
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
                            _isEditing ? context.l10n.editBusinessTitle : context.l10n.listYourBusiness,
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
                              ? context.l10n.updateBusinessInfo
                              : context.l10n.getBusinessListed,
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
                                    context.l10n.businessDetails,
                                    style: TextStyle(
                                      color: _onSurface,
                                      fontSize: _rs(0.05, min: 16, max: 22),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ]),
                              Divider(color: _subtleBorder, height: 20),
                              _buildLabel(context.l10n.businessName),
                              const SizedBox(height: 6),
                              _buildTextField(
                                controller: _businessNameController,
                                hintText: context.l10n.businessNameHint,
                                isRequired: true,
                              ),
                              const SizedBox(height: 14),
                              _buildLabel(context.l10n.serviceCategoriesLabel),
                              const SizedBox(height: 6),
                              _buildServiceCategorySelector(),
                              const SizedBox(height: 14),
                              _buildLabel(context.l10n.districtLabel),
                              const SizedBox(height: 6),
                              _buildDropdown(
                                value: _selectedDistrict,
                                hint: context.l10n.selectDistrict,
                                items: _districtLocalities.keys.toList(),
                                onChanged: (value) => setState(() {
                                  _selectedDistrict = value;
                                  _selectedLocality = null;
                                }),
                                isRequired: true,
                              ),
                              const SizedBox(height: 14),
                              _buildLabel(context.l10n.localityLabel),
                              const SizedBox(height: 6),
                              _buildDropdown(
                                value: _selectedLocality,
                                hint: _selectedDistrict == null
                                    ? context.l10n.selectDistrictFirst
                                    : context.l10n.selectLocality,
                                items: _selectedDistrict != null
                                    ? _districtLocalities[_selectedDistrict]!
                                    : [],
                                onChanged: _selectedDistrict != null
                                    ? (value) => setState(() => _selectedLocality = value)
                                    : null,
                                isRequired: true,
                              ),
                              const SizedBox(height: 14),
                              _buildLabel(context.l10n.businessDescriptionOptional),
                              const SizedBox(height: 6),
                              _buildTextField(
                                controller: _businessDescriptionController,
                                hintText: context.l10n.descriptionHint,
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
                                    context.l10n.contactInfo,
                                    style: TextStyle(
                                      color: _onSurface,
                                      fontSize: _rs(0.05, min: 16, max: 22),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ]),
                              Divider(color: _subtleBorder, height: 20),

                              _buildLabel(context.l10n.businessPhoneLabel),
                              const SizedBox(height: 6),
                              _buildPhoneRow(
                                controller: _phoneController,
                                hintText: '9876543210',
                                isRequired: true,
                                // Locked to the number verified at login. If the
                                // session has none, it stays editable so nobody is stuck.
                                readOnly: _verifiedPhone != null,
                              ),
                              const SizedBox(height: 14),
                              Row(children: [
                                Icon(Icons.chat_bubble_outline, color: _onSurfaceMuted),
                                const SizedBox(width: 8),
                                Text(context.l10n.whatsapp, style: TextStyle(color: _onSurfaceMuted)),
                              ]),
                              // Tick to use the business number for WhatsApp too.
                              InkWell(
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                onTap: () => setState(() {
                                  _whatsappSame = !_whatsappSame;
                                  _whatsappController.text =
                                      _whatsappSame ? _phoneController.text.trim() : '';
                                }),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(children: [
                                    SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: Checkbox(
                                        value: _whatsappSame,
                                        activeColor: AppColors.primary,
                                        visualDensity: VisualDensity.compact,
                                        onChanged: (v) => setState(() {
                                          _whatsappSame = v ?? false;
                                          _whatsappController.text = _whatsappSame
                                              ? _phoneController.text.trim()
                                              : '';
                                        }),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(context.l10n.sameAsBusinessNumber,
                                          style: TextStyle(
                                              color: _onSurface,
                                              fontSize: AppText.secondary)),
                                    ),
                                  ]),
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buildPhoneRow(
                                controller: _whatsappController,
                                hintText: context.l10n.sameOrDifferent,
                                readOnly: _whatsappSame,
                              ),
                              const SizedBox(height: 14),
                              Row(children: [
                                Icon(Icons.email_outlined, color: _onSurfaceMuted),
                                const SizedBox(width: 8),
                                Text(context.l10n.email, style: TextStyle(color: _onSurfaceMuted)),
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
                                Text(context.l10n.address, style: TextStyle(color: _onSurfaceMuted)),
                              ]),
                              const SizedBox(height: 6),
                              _buildTextField(
                                controller: _addressController,
                                hintText: context.l10n.shopOfficeAddress,
                              ),
                              const SizedBox(height: 14),
                              _buildSwitchTile(
                                icon: Icons.home_outlined,
                                label: context.l10n.homeServiceAvailable,
                                value: _homeServiceAvailable,
                                onChanged: (v) => setState(() => _homeServiceAvailable = v),
                              ),
                              const SizedBox(height: 10),
                              _buildSwitchTile(
                                icon: Icons.payment_outlined,
                                label: context.l10n.acceptOnlinePayment,
                                value: _acceptOnlinePayment,
                                onChanged: (v) => setState(() => _acceptOnlinePayment = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                              if (!_isEditing) ...[
                                Row(children: [
                                  Icon(Icons.hourglass_empty, color: AppColors.warning),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      context.l10n.listingReviewNote,
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
                                final buttonStyle_outlined = AppButtons.secondary;
                                final buttonStyle_filled = AppButtons.primary;

                                final cancelBtn = OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: buttonStyle_outlined,
                                  child: Text(context.l10n.cancel,
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
                                    _isEditing ? context.l10n.saveChanges : context.l10n.submit,
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
    bool readOnly = false,
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
          borderRadius: BorderRadius.circular(AppRadius.sm),
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
          readOnly: readOnly,
        ),
      ),
    ]);
  }

  // ── Service category multi-selector ──────────────────────────────────────
  Widget _buildServiceCategorySelector() {
    final selBg = AppColors.primary.withOpacity(0.12);

    _ServiceOption? byName(String n) {
      for (final o in _serviceOptions) {
        if (o.name == n) return o;
      }
      return null;
    }

    Widget chip(String name) {
      final o = byName(name);
      return Container(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 5, 6, 5),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (o != null) ...[
            Icon(o.icon, size: 15, color: o.iconColor),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              categoryName(context, _slugForService(name), name),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: _onSurface,
                  fontSize: AppText.secondary,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => setState(() => _selectedServiceTypes.remove(name)),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 16, color: _onSurfaceMuted),
            ),
          ),
        ]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The field: placeholder, or the chosen categories as removable chips.
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: () => setState(() {
            _serviceDropdownOpen = !_serviceDropdownOpen;
            if (!_serviceDropdownOpen) {
              _searchController.clear();
              _searchQuery = '';
            }
            _serviceTypeError = false;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 10, 12),
            constraints: const BoxConstraints(minHeight: 54),
            decoration: BoxDecoration(
              color: _inputFill,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: _serviceTypeError
                    ? AppColors.danger
                    : _serviceDropdownOpen
                        ? AppColors.primary
                        : _borderColor,
                width: (_serviceTypeError || _serviceDropdownOpen) ? 1.5 : 1,
              ),
            ),
            child: Row(children: [
              Expanded(
                child: _selectedServiceTypes.isEmpty
                    ? Text(
                        context.l10n.selectUpTo3,
                        style: TextStyle(
                          color: _onSurfaceMuted,
                          fontSize: _rs(0.037, min: 13, max: 16),
                        ),
                      )
                    : Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final n in _selectedServiceTypes) chip(n),
                      ]),
              ),
              AnimatedRotation(
                turns: _serviceDropdownOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: _onSurfaceMuted),
              ),
            ]),
          ),
        ),
        // The list: a separate card under the field, in the app's own colours.
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: !_serviceDropdownOpen
              ? const SizedBox(width: double.infinity)
              : Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: AppColors.solid(_cs),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: _subtleBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: _onSurface, fontSize: AppText.body),
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: context.l10n.searchCategories,
                          hintStyle: TextStyle(
                              color: _onSurfaceMuted, fontSize: AppText.body),
                          prefixIcon:
                              Icon(Icons.search, color: _onSurfaceMuted, size: 20),
                          filled: true,
                          fillColor: _inputFill,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 11),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    // Height follows the screen (180 to 300 px).
                    SizedBox(
                      height: _rs(0.35, min: 180, max: 300),
                      child: _filteredOptions.isEmpty
                          ? Center(
                              child: Text(context.l10n.noProvidersFound,
                                  style: TextStyle(color: _onSurfaceMuted)))
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 6),
                              physics: const BouncingScrollPhysics(),
                              itemCount: _filteredOptions.length,
                              itemBuilder: (context, index) {
                                final option = _filteredOptions[index];
                                final isSelected =
                                    _selectedServiceTypes.contains(option.name);
                                final isDisabled = !isSelected &&
                                    _selectedServiceTypes.length >= 3;

                                return InkWell(
                                  onTap: isDisabled
                                      ? null
                                      : () => setState(() {
                                            if (isSelected) {
                                              _selectedServiceTypes
                                                  .remove(option.name);
                                            } else {
                                              _selectedServiceTypes.add(option.name);
                                              // Picked a category: close the list.
                                              _serviceDropdownOpen = false;
                                              _searchController.clear();
                                              _searchQuery = '';
                                            }
                                          }),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: _rs(0.025, min: 8, max: 12),
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? selBg
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.sm),
                                    ),
                                    child: Row(children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: option.iconColor.withOpacity(
                                              isDisabled ? 0.06 : 0.14),
                                          borderRadius: BorderRadius.circular(11),
                                        ),
                                        child: Icon(
                                          option.icon,
                                          size: 20,
                                          color: isDisabled
                                              ? _onSurface.withOpacity(0.25)
                                              : option.iconColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          categoryName(
                                              context, option.slug, option.name),
                                          style: TextStyle(
                                            color: isDisabled
                                                ? _onSurface.withOpacity(0.35)
                                                : _onSurface,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontSize: _rs(0.037, min: 13, max: 16),
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(Icons.check_circle_rounded,
                                            color: AppColors.primary, size: 22),
                                    ]),
                                  ),
                                );
                              },
                            ),
                    ),
                  ]),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          context.l10n.categoriesSelected(_selectedServiceTypes.length),
          style: TextStyle(
            color: _serviceTypeError ? AppColors.danger : _onSurfaceMuted,
            fontSize: AppText.caption,
          ),
        ),
        if (_serviceTypeError)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(context.l10n.selectAtLeastOneService,
                style: TextStyle(color: AppColors.danger, fontSize: AppText.caption)),
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
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: _onSurface, fontSize: _rs(0.038, min: 13, max: 16)),
      validator: isRequired
          ? (value) {
        if (value == null || value.trim().isEmpty) return context.l10n.fieldRequired;
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
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: _kTeal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        errorStyle: const TextStyle(color: AppColors.danger, fontSize: AppText.caption),
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
        if (value == null || value.isEmpty) return context.l10n.pleaseSelectOption;
        return null;
      }
          : null,
      dropdownColor: _isDark ? const Color(0xFF1E2E2E) : AppColors.solid(_cs),
      style: TextStyle(
          color: _onSurface,
          fontSize: _rs(0.038, min: 13, max: 16)),
      icon: Icon(Icons.keyboard_arrow_down, color: _onSurfaceMuted),
      decoration: InputDecoration(
        filled: true,
        fillColor: _inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: _kTeal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        errorStyle: const TextStyle(color: AppColors.danger, fontSize: AppText.caption),
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
      showAppSnack(context, context.l10n.selectAtLeastOneService, type: SnackType.error, duration: const Duration(seconds: 3));
      return;
    }

    if (!_formKey.currentState!.validate()) {
      showAppSnack(context, context.l10n.fillRequiredFields, type: SnackType.error, duration: const Duration(seconds: 3));
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
        final res = await sharedHttp.get(
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
        final patchRes = await sharedHttp.patch(
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

        await sharedHttp.delete(
          Uri.parse('$_supabaseUrl/rest/v1/vendor_categories?vendor_id=eq.$vendorId'),
          headers: headers,
        );
        await sharedHttp.post(
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

        final vendorRes = await sharedHttp.post(
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

        await sharedHttp.post(
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
      _showErrorDialog(context.l10n.networkCheckConnection);
      debugPrint('Error submitting vendor: $e');
    }
  }

  void _showSuccessDialog({bool isEdit = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.successTitle,
            style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurface,
                fontWeight: FontWeight.bold)),
        content: Text(
          isEdit
              ? context.l10n.businessUpdatedMsg
              : context.l10n.businessSubmittedMsg,
          style: TextStyle(
              color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text(context.l10n.ok, style: TextStyle(color: _kTeal)),
          ),
        ]),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.errorTitle,
            style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
        content: Text(message,
            style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.ok, style: TextStyle(color: _kTeal)),
          ),
        ]),
    );
  }
}