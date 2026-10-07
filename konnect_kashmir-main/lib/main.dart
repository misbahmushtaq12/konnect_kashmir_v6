import 'package:flutter/material.dart';
import 'package:konnect_kashmir/screens/login_screen.dart';
import 'package:konnect_kashmir/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/main_shell.dart';
import 'screens/customer_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/vendor_screen.dart';
import 'static/terms_screen.dart';
import 'static/privacy_screen.dart';
import 'static/refund_screen.dart';
import 'static/grevience_screen.dart';
import 'static/contact_screen.dart';
import 'screens/role_selection.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'theme/app_theme.dart';
import 'widgets/theme_reveal.dart';

final facebookAppEvents = FacebookAppEvents();

// ── 1. Make main() async and restore session before runApp ──────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable Facebook SDK auto event logging (app installs/opens)
  await facebookAppEvents.setAutoLogAppEventsEnabled(true);
  debugPrint('✅ Facebook App Events initialized');

  // Restore saved login session (if user was previously logged in)
  final authProvider = AuthProvider();
  await authProvider.restoreSession();

  await Supabase.initialize(
    url: 'https://fmmpsqnpezjofsluirrv.supabase.co',
    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZtbXBzcW5wZXpqb2ZzbHVpcnJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2MzIyNTgsImV4cCI6MjA4NTIwODI1OH0.6FCU_FLaHsKsE7G50A7-_zYf46GZiKpecg4l_de3tn4',
  );
  AuthService.initialize();
  final themeProvider = await ThemeProvider.load();
  runApp(KonnectKashmirApp(
      authProvider: authProvider, themeProvider: themeProvider));
}

final supabase = Supabase.instance.client;

class KonnectKashmirApp extends StatelessWidget {
  final AuthProvider authProvider;
  final ThemeProvider themeProvider;
  const KonnectKashmirApp(
      {super.key, required this.authProvider, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ── 2. Use the already-initialised provider (not a fresh one) ──────
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeState, _) => MaterialApp(
        title: 'KonnectKashmir',
        debugShowCheckedModeBanner: false,

        // ── Light/dark follow the device; styling lives in theme/app_theme.dart
        themeMode: themeState.mode,
        // The reveal overlay handles the visual change; no per-frame colour lerp.
        themeAnimationDuration: Duration.zero,
        builder: (context, child) => ThemeReveal(child: child!),
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,

        // Flow: Splash -> Login (or Dashboard if already signed in)
        home: const SplashScreen(),

        routes: {
          '/home':            (_) => const MainShell(),
          '/login':           (_) => const LoginScreen(redirectMessage: 'Please sign in to continue'),
          '/customer':        (_) => const CustomerScreen(),
          '/vendors':         (_) => const CustomerScreen(),
          '/dashboard':       (_) => const DashboardScreen(),
          '/register-vendor': (_) => const ListBusinessScreen(),
          '/jobs':            (_) => const _PlaceholderScreen(title: 'Jobs Coming Soon'),
          '/contact':         (_) => const ContactScreen(),
          '/terms':           (_) => const TermsScreen(),
          '/privacy':         (_) => const PrivacyScreen(),
          '/refund':          (_) => const RefundPolicy(),
          '/grievance':       (_) => const GrievanceScreen(),
        },
        ),
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF212721),
      appBar: AppBar(
        backgroundColor: const Color(0xFF212721),
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: Center(
        child: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}