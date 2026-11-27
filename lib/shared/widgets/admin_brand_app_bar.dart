import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/dashboard/providers/dashboard_providers.dart';
import '../../features/notifications/providers/notifications_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import 'fitflow_logo.dart';

class AdminBrandAppBar extends ConsumerWidget {
  const AdminBrandAppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider).valueOrNull;
    final admin = authState?.admin;
    final activeGymId = authState?.activeGymId;
    final gymsAsync = ref.watch(myGymsProvider);
    final settingsAsync = ref.watch(activeGymSettingsProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    final gyms = gymsAsync.valueOrNull ?? const <GymSimple>[];
    final branding = AccessControl.resolveGymBranding(
      admin: admin,
      gyms: gyms,
      activeGymId: activeGymId,
      settings: settingsAsync.valueOrNull,
      defaultName: l10n.activeBranchDefault,
    );
    final activeGymName = branding.name;
    final primary = Theme.of(context).colorScheme.primary;

    final roleLabel = admin?.roleBadgeLabel ?? l10n.roleAdmin;

    return SafeArea(
      bottom: false,
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(
            bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: GymBrandHeaderLogo(
                            branding: branding,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primary.withAlpha(36),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(
                          roleLabel,
                          style: GoogleFonts.figtree(
                            color: primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  InkWell(
                    onTap: gyms.length > 1
                        ? () => showGymSwitcherBottomSheet(
                              context,
                              ref,
                              gyms,
                              activeGymId,
                            )
                        : null,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              activeGymName,
                              style: GoogleFonts.figtree(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            LucideIcons.chevronDown,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: () => context.push(AppRoutes.notifications),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      LucideIcons.bell,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        top: 9,
                        right: 10,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
