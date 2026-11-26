import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/drawer_menu_button.dart';

class HelpCenterScreen extends ConsumerWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final admin = ref.watch(authProvider).valueOrNull?.admin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: Text(l10n.helpCenterTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            l10n.helpCenterSubtitle,
            style: GoogleFonts.figtree(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          const _GuideCard(
            icon: LucideIcons.qrCode,
            title: 'Check-in QR & Manual',
            description:
                'Gunakan tab Scan QR untuk memindai QR member, atau tab Check-in manual untuk mencari nama/ID member dan konfirmasi kehadiran secara langsung.',
          ),
          const SizedBox(height: 12),
          const _GuideCard(
            icon: LucideIcons.dumbbell,
            title: 'GYM SESSIONS vs PT SESSIONS',
            description:
                'GYM SESSIONS adalah kuota kunjungan masuk gym mandiri yang berkurang saat check-in. PT SESSIONS adalah sesi tatap muka 1-on-1 bersama Personal Trainer.',
          ),
          const SizedBox(height: 12),
          const _GuideCard(
            icon: LucideIcons.monitor,
            title: 'POS & Transaksi',
            description:
                'Catat penjualan produk ritel dari menu POS dan pantau riwayat pembayaran lengkap di menu Transaksi.',
          ),
          const SizedBox(height: 24),
          if (admin != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      LucideIcons.user,
                      color: AppColors.accent,
                    ),
                    title: Text(
                      admin.name,
                      style: GoogleFonts.figtree(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      admin.email,
                      style: GoogleFonts.figtree(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(
                      LucideIcons.chevronRight,
                      color: AppColors.textSecondary,
                    ),
                    onTap: () => context.push(AppRoutes.profile),
                  ),
                  const Divider(color: AppColors.border),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      LucideIcons.logOut,
                      color: AppColors.error,
                    ),
                    title: Text(
                      l10n.logoutAction,
                      style: GoogleFonts.figtree(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () => ref.read(authProvider.notifier).logout(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.iconSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.figtree(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.figtree(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.45,
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
