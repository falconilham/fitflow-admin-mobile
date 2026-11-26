import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_utils.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';

final myGymsProvider = FutureProvider.autoDispose<List<GymSimple>>((ref) async {
  return ref.read(apiRepositoryProvider).getMyGyms();
});

final dashboardStatsProvider =
    FutureProvider.autoDispose<DashboardStats>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) {
    return const DashboardStats(
      totalMembers: 0,
      activeMembers: 0,
      dailyCheckIns: 0,
      expenses: 0,
    );
  }
  return ref.read(apiRepositoryProvider).getStats(gymId);
});

final expiringMembersProvider =
    FutureProvider.autoDispose<List<ExpiringMember>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return <ExpiringMember>[];
  return ref.read(apiRepositoryProvider).getExpiringMembers(gymId, limit: 5);
});

final recentCheckInsProvider =
    FutureProvider.autoDispose<List<CheckInRecord>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return <CheckInRecord>[];
  return ref.read(apiRepositoryProvider).getRecentCheckIns(gymId, limit: 5);
});

final activeGymSettingsProvider =
    FutureProvider.autoDispose<GymSettings?>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return null;
  try {
    return await ref.read(apiRepositoryProvider).getGymSettings(gymId);
  } catch (_) {
    return null;
  }
});

Future<void> showGymSwitcherBottomSheet(
  BuildContext context,
  WidgetRef ref,
  List<GymSimple> gyms,
  int? activeGymId,
) async {
  final l10n = AppLocalizations.of(context)!;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.selectBranchTitle,
                    style: GoogleFonts.figtree(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      LucideIcons.x,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: gyms.length,
                  itemBuilder: (_, index) {
                    final gym = gyms[index];
                    final active = gym.id == activeGymId;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        backgroundColor:
                            active ? AppColors.accent : AppColors.card,
                        child: Text(
                          gym.name.isNotEmpty
                              ? gym.name[0].toUpperCase()
                              : 'G',
                          style: GoogleFonts.figtree(
                            color: active
                                ? AppColors.background
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(
                        gym.name,
                        style: GoogleFonts.figtree(
                          color: active
                              ? AppColors.accent
                              : AppColors.textPrimary,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      trailing: active
                          ? const Icon(
                              LucideIcons.checkCircle2,
                              color: AppColors.accent,
                            )
                          : null,
                      onTap: () async {
                        ref.read(authProvider.notifier).setActiveGym(gym.id);
                        await AuthUtils.setGymId(gym.id.toString());
                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
