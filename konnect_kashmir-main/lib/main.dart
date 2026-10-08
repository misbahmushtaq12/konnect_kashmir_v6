import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:konnect_kashmir/screens/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'services/backend_config.dart';
import 'services/live_sync.dart';
import 'services/notification_service.dart';
import 'l10n/app_localizations.dart';
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

  // Everything the first screen needs is loaded at the same time instead of one
  // after the other, so the app opens sooner.
  final authProvider = AuthProvider();
  final results = await Future.wait<Object?>([
    authProvider.restoreSession(), // keeps the user signed in
    Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey),
    ThemeProvider.load(),
    LocaleProvider.load(),
  ]);
  final themeProvider = results[2] as ThemeProvider;
  final localeProvider = results[3] as LocaleProvider;
  final liveSync = LiveSync(authProvider);

  runApp(KonnectKashmirApp(
      authProvider: authProvider,
      themeProvider: themeProvider,
      localeProvider: localeProvider,
      liveSync: liveSync));

  // Not needed to draw the first screen, so they start after it.
  facebookAppEvents.setAutoLogAppEventsEnabled(true);
  NotificationService.instance.start(authProvider);
  // Fetch the balance while the splash plays; Home then reuses it.
  if (authProvider.isAuthenticated) liveSync.refreshCredits();
}

final supabase = Supabase.instance.client;

class KonnectKashmirApp extends StatelessWidget {
  final AuthProvider authProvider;
  final ThemeProvider themeProvider;
  final LocaleProvider localeProvider;
  final LiveSync liveSync;
  const KonnectKashmirApp({
    super.key,
    required this.authProvider,
    required this.themeProvider,
    required this.localeProvider,
    required this.liveSync,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ── 2. Use the already-initialised provider (not a fresh one) ──────
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: localeProvider),
        ChangeNotifierProvider.value(value: liveSync),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, themeState, localeState, _) => MaterialApp(
        title: 'KonnectKashmir',
        navigatorKey: appNavigatorKey,
        debugShowCheckedModeBanner: false,

        // Language (English / Hindi / Urdu). Urdu automatically flips the layout RTL.
        locale: localeState.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],

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
          style: const TextStyle(color: Colors.white, fontSize: AppText.heading),
        ),
      ),
    );
  }
}