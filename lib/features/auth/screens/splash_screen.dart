import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Brand Component Widget
            RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2.5,
                ),
                children: [
                  const TextSpan(
                    text: 'FIT',
                    style: TextStyle(color: Colors.white),
                  ),
                  TextSpan(
                    text: 'FLOW.ID',
                    style: const TextStyle(color: AppColors.accent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 2,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ADMIN PANEL',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
