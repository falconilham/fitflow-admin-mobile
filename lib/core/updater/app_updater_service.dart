import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:restart_app/restart_app.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../theme/app_theme.dart';

class AppUpdaterService {
  static final ShorebirdUpdater _updater = ShorebirdUpdater();
  static bool _isChecking = false;

  /// Returns clean Semantic Versioning (SemVer) string:
  /// Examples:
  /// - Base release: "v1.0.0"
  /// - With OTA Patch: "v1.0.0 • Patch #1"
  static Future<String> getSemVerVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final baseVersion = packageInfo.version;

      if (_updater.isAvailable) {
        final currentPatch = await _updater.readCurrentPatch();
        if (currentPatch != null && currentPatch.number > 0) {
          return 'v$baseVersion • Patch #${currentPatch.number}';
        }
      }
      return 'v$baseVersion';
    } catch (_) {
      return 'v1.0.0';
    }
  }

  /// Checks for available updates and prompts user with animated FitFlow-styled UI dialog
  static Future<void> checkForUpdates(
    BuildContext context, {
    bool isManual = false,
  }) async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      if (!_updater.isAvailable) {
        if (isManual && context.mounted) {
          _showCustomSnackBar(
            context,
            message: 'Shorebird Code Push aktif pada versi rilis (Release Mode).',
            isError: false,
          );
        }
        return;
      }

      final status = await _updater.checkForUpdate();
      if (!context.mounted) return;

      switch (status) {
        case UpdateStatus.outdated:
          _showUpdateAvailableDialog(context);
          break;
        case UpdateStatus.restartRequired:
          _showRestartRequiredDialog(context);
          break;
        case UpdateStatus.upToDate:
          if (isManual) {
            final version = await getSemVerVersion();
            if (context.mounted) {
              _showCustomSnackBar(
                context,
                message: 'FitFlow Admin sudah menggunakan versi terbaru ($version).',
                isError: false,
              );
            }
          }
          break;
        case UpdateStatus.unavailable:
          if (isManual && context.mounted) {
            _showCustomSnackBar(
              context,
              message: 'Server pembaruan sedang tidak dapat dijangkau.',
              isError: true,
            );
          }
          break;
      }
    } catch (e) {
      if (isManual && context.mounted) {
        _showCustomSnackBar(
          context,
          message: 'Gagal memeriksa pembaruan: $e',
          isError: true,
        );
      }
    } finally {
      _isChecking = false;
    }
  }

  /// Initial prompt when an update is found
  static void _showUpdateAvailableDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.accent.withAlpha(120),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.accent,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pembaruan Tersedia',
                        style: GoogleFonts.outfit(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Over-The-Air Patch',
                            style: GoogleFonts.outfit(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Versi perbaikan baru siap diunduh (~300 KB). Unduh sekarang untuk mendapatkan fitur & kestabilan terbaru?',
              style: GoogleFonts.outfit(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Nanti',
              style: GoogleFonts.outfit(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _downloadUpdateWithAnimation(context);
            },
            child: Text(
              'Unduh Sekarang',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Download with custom neon glow pulse animation dialog
  static Future<void> _downloadUpdateWithAnimation(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) => const _AnimatedDownloadDialog(),
    );

    try {
      await _updater.update();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss animated dialog
      _showRestartRequiredDialog(context);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss animated dialog
      _showCustomSnackBar(
        context,
        message: 'Gagal mengunduh pembaruan: $e',
        isError: true,
      );
    }
  }

  /// Success dialog with pop animation prompting restart
  static void _showRestartRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (restartContext) => const _AnimatedSuccessDialog(),
    );
  }

  /// Custom SnackBar matching FitFlow Theme
  static void _showCustomSnackBar(
    BuildContext context, {
    required String message,
    required bool isError,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isError ? AppColors.error : AppColors.accent.withAlpha(100),
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated Download Dialog with Glowing Pulse & Shimmer
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedDownloadDialog extends StatefulWidget {
  const _AnimatedDownloadDialog();

  @override
  State<_AnimatedDownloadDialog> createState() => _AnimatedDownloadDialogState();
}

class _AnimatedDownloadDialogState extends State<_AnimatedDownloadDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _rotateAnimation;
  Timer? _dotsTimer;
  int _dotCount = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _rotateAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _dotsTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) {
        setState(() {
          _dotCount = (_dotCount % 3) + 1;
        });
      }
    });
  }

  @override
  void dispose() {
    _dotsTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dotCount;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 310,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(180),
                blurRadius: 28,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing Animated Pulse Icon
              SizedBox(
                height: 90,
                width: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulsing glow circle
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 72 * _pulseAnimation.value,
                          height: 72 * _pulseAnimation.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent.withAlpha(25),
                            border: Border.all(
                              color: AppColors.accent.withAlpha(90),
                              width: 1.5,
                            ),
                          ),
                        );
                      },
                    ),
                    // Inner Neon Container with rotating sync icon
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withAlpha(100),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: RotationTransition(
                          turns: _rotateAnimation,
                          child: const Icon(
                            Icons.sync_rounded,
                            color: Colors.black,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Mengunduh Pembaruan$dots',
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ukuran patch ~300 KB • hanya beberapa detik',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              // Electric Lime Progress Indicator
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: const LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: AppColors.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated Success Dialog with Elastic Scale Pop & Restart Button
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedSuccessDialog extends StatefulWidget {
  const _AnimatedSuccessDialog();

  @override
  State<_AnimatedSuccessDialog> createState() => _AnimatedSuccessDialogState();
}

class _AnimatedSuccessDialogState extends State<_AnimatedSuccessDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    _scaleController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 26, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.success.withAlpha(140),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withAlpha(60),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pembaruan Siap!',
                        style: GoogleFonts.outfit(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Patch Berhasil Diunduh',
                        style: GoogleFonts.outfit(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Pembaruan sistem telah berhasil diunduh ke perangkat. Muat ulang aplikasi sekarang untuk langsung menerapkan fitur & perbaikan terbaru?',
              style: GoogleFonts.outfit(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Nanti',
              style: GoogleFonts.outfit(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await Restart.restartApp();
              } catch (_) {
                // Fallback: user can close and reopen
              }
            },
            icon: const Icon(Icons.restart_alt_rounded, size: 20, color: Colors.black),
            label: Text(
              'Muat Ulang Sekarang',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
