import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

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
    return MaterialApp.router(
      title: 'FitFlow Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
