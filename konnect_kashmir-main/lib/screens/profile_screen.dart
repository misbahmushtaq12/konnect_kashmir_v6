import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:konnect_kashmir/providers/auth_provider.dart';
import 'main_shell.dart';

class CompleteProfileScreen extends StatefulWidget {
  final String role;
  final String phone;
  final String userId;

  const CompleteProfileScreen({
    super.key,
    required this.role,
    required this.phone,
    required this.userId,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  bool _isLoading = false;
  String? _error;

  static const String _baseUrl = 'https://fmmpsqnpezjofsluirrv.supabase.co';
  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZtbXBzcW5wZXpqb2ZzbHVpcnJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2MzIyNTgsImV4cCI6MjA4NTIwODI1OH0.6FCU_FLaHsKsE7G50A7-_zYf46GZiKpecg4l_de3tn4';

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your full name');
      return;
    }
    if (name.length < 2) {
      setState(() => _error = 'Name must be at least 2 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      final uri = Uri.parse('$_baseUrl/rest/v1/profiles')
          .replace(queryParameters: {'id': 'eq.${widget.userId}'});

      final res = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'apikey': _anonKey,
          'Authorization': 'Bearer $token',
          'Prefer': 'return=representation',
        },
        body: jsonEncode({'full_name': name}),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timed out. Please try again.'),
      );

      if (res.statusCode != 200 && res.statusCode != 204) {
        String errMsg = 'Failed to save name (${res.statusCode})';
        try {
          final body = jsonDecode(res.body);
          errMsg = body['message'] ?? body['error'] ?? errMsg;
        } catch (_) {}
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = errMsg;
          });
        }
        return;
      }

      await prefs.setString('user_name', name);

      // FIX 1: single mounted check wrapping both refresh and navigate
      if (!mounted) return;
      await context.read<AuthProvider>().refreshProfile();

      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
            (route) => false,
      );

      // FIX 2: catch ALL errors not just Exception
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size  = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(color: theme.scaffoldBackgroundColor),
            ),

            Positioned.fill(
              child: Center(
                child: Opacity(
                  opacity: 0.18,
                  child: Image.asset(
                    'assets/images/chinar.png',
                    width: size.width,
                    height: size.height,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    // FIX 3: responsive horizontal padding
                    horizontal: size.width > 600 ? size.width * 0.15 : 24,
                    vertical: 32,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      // FIX 4: max width so card never goes too wide on tablets
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: _ProfileCard(
                        size: size,
                        nameController: _nameController,
                        nameFocus: _nameFocus,
                        isLoading: _isLoading,
                        error: _error,
                        onContinue: _saveName,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final Size size;
  final TextEditingController nameController;
  final FocusNode nameFocus;
  final bool isLoading;
  final String? error;
  final VoidCallback onContinue;

  const _ProfileCard({
    required this.size,
    required this.nameController,
    required this.nameFocus,
    required this.isLoading,
    required this.error,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;

    // FIX 5: responsive font sizes based on screen width
    final double titleSize    = size.width < 360 ? 18 : 22;
    final double subtitleSize = size.width < 360 ? 12 : 13.5;
    final double iconSize     = size.width < 360 ? 52 : 64;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.primary.withOpacity(0.35),
          width: 1.2,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Opacity(
                opacity: 0.18,
                child: Image.asset(
                  'assets/images/chinar.png',
                  // FIX 6: cap watermark width so it doesn't overflow on wide screens
                  width: size.width > 600 ? 300 : size.width * 0.75,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(
              // FIX 7: slightly more padding on wider cards
              size.width > 600 ? 32 : 24,
              36,
              size.width > 600 ? 32 : 24,
              36,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: cs.primary.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: cs.primary,
                    size: iconSize * 0.5,
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Complete Your Profile',
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 10),

                Text(
                  'Please enter your name to continue using KonnectKashmir',
                  style: TextStyle(
                    fontSize: subtitleSize,
                    color: cs.onSurface.withOpacity(0.55),
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                Align(
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Your Full Name ',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const TextSpan(
                          text: '*',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: nameController,
                  focusNode: nameFocus,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  // FIX 8: prevent accidental form submit on enter key on tablets
                  textInputAction: TextInputAction.done,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter your full name',
                    hintStyle: TextStyle(
                      color: cs.onSurface.withOpacity(0.35),
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                    filled: true,
                    fillColor: cs.onSurface.withOpacity(0.07),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: cs.primary.withOpacity(0.4),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: cs.primary.withOpacity(0.4),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: cs.primary,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.red.withOpacity(0.6),
                      ),
                    ),
                  ),
                  onSubmitted: (_) => onContinue(),
                ),

                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'This will be visible to vendors when you contact them',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurface.withOpacity(0.4),
                    ),
                  ),
                ),

                if (error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      border: Border.all(color: Colors.red.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      error!,
                      style: TextStyle(color: Colors.red[400], fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary.withOpacity(0.15),
                      foregroundColor: cs.primary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: cs.primary.withOpacity(0.4)),
                      ),
                      disabledBackgroundColor: cs.primary.withOpacity(0.08),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(cs.primary),
                      ),
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_forward,
                            size: 18, color: cs.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}