import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/models/models.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/dashboard/providers/dashboard_providers.dart';
import 'l10n/generated/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Global error handler ─────────────────────────────────────────────────
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('═══════════════ FLUTTER ERROR ═══════════════');
    debugPrint('${details.exception}');
    debugPrint('${details.stack}');
    debugPrint('═════════════════════════════════════════════');
  };

  // Catch async errors not caught by Flutter framework
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('═══════════════ PLATFORM ERROR ══════════════');
    debugPrint('$error');
    debugPrint('$stack');
    debugPrint('═════════════════════════════════════════════');
    return true;
  };

  await dotenv.load(fileName: '.env');
  await initializeDateFormatting('id_ID', null);
  runApp(const ProviderScope(child: FitFlowAdminApp()));
}

class FitFlowAdminApp extends ConsumerWidget {
  const FitFlowAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final authState = ref.watch(authProvider).valueOrNull;
    final isAuthenticated = authState?.isAuthenticated == true;
    final gyms = isAuthenticated
        ? (ref.watch(myGymsProvider).valueOrNull ?? const <GymSimple>[])
        : const <GymSimple>[];
    final settings = isAuthenticated
        ? ref.watch(activeGymSettingsProvider).valueOrNull
        : null;

    final branding = isAuthenticated
        ? AccessControl.resolveGymBranding(
            admin: authState?.admin,
            gyms: gyms,
            activeGymId: authState?.activeGymId,
            settings: settings,
          )
        : const GymBranding(name: 'FitFlow Admin');

    final customPrimary = branding.hasWhiteLabel
        ? AppTheme.parseHexColor(branding.primaryColor)
        : null;
    final customSecondary = branding.hasWhiteLabel
        ? AppTheme.parseHexColor(branding.secondaryColor)
        : null;

    return MaterialApp.router(
      title: branding.hasWhiteLabel ? branding.name : 'FitFlow Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(
        customPrimary: customPrimary,
        customSecondary: customSecondary,
      ),
      routerConfig: router,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
