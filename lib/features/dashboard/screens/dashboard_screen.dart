import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/drawer_menu_button.dart';
import '../../../shared/utils/error_handler.dart';

// ── Providers ──────────────────────────────────────────────────────────────

final myGymsProvider = FutureProvider.autoDispose<List<GymSimple>>((ref) async {
  return ref.read(apiRepositoryProvider).getMyGyms();
});

final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return const DashboardStats(totalMembers: 0, activeMembers: 0, dailyCheckIns: 0, expenses: 0);
  return ref.read(apiRepositoryProvider).getStats(gymId);
});

final recentCheckInsProvider = FutureProvider.autoDispose<List<CheckInRecord>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return <CheckInRecord>[];
  return ref.read(apiRepositoryProvider).getRecentCheckIns(gymId, limit: 5);
});

// ── Screen ──────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider).valueOrNull;
    final admin = authState?.admin;
    final activeGymId = authState?.activeGymId;
    final statsAsync = ref.watch(dashboardStatsProvider);
    final checkInsAsync = ref.watch(recentCheckInsProvider);
    final gymsAsync = ref.watch(myGymsProvider);

    // Auto-set gymId from first gym when owner has no gymId yet
    ref.listen(myGymsProvider, (_, next) {
      next.whenData((gyms) {
        if (activeGymId == null && gyms.isNotEmpty) {
          ref.read(authProvider.notifier).setActiveGym(gyms.first.id);
        }
      });
    });

    final activeGymName = gymsAsync.valueOrNull?.firstWhere(
          (g) => g.id == activeGymId,
          orElse: () => GymSimple(id: 0, name: admin?.gym?.name ?? 'My Gym'),
        ).name ?? admin?.gym?.name ?? 'My Gym';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: GestureDetector(
          onTap: () {
            final gyms = gymsAsync.valueOrNull ?? [];
            if (gyms.length > 1) {
              _showGymSwitcherBottomSheet(context, ref, gyms, activeGymId);
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  activeGymName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if ((gymsAsync.valueOrNull?.length ?? 0) > 1) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textMuted),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.card,
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(recentCheckInsProvider);
          ref.invalidate(myGymsProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              color: AppColors.surface,
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Overview',
                    style: TextStyle(color: AppColors.accent, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
                SizedBox(height: 6),
                Text('Real-time performance summary',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),

            // Stats
            Padding(
              padding: const EdgeInsets.all(16),
              child: statsAsync.when(
                loading: () => _StatsGridSkeleton(),
                error: (e, _) => _ErrorCard(message: ErrorHandler.parse(e)),
                data: (s) => GridView.count(
                  crossAxisCount: 2, shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.3,
                  children: [
                    _StatCard(label: 'Total Member', value: s.totalMembers.toString(), color: AppColors.accent),
                    _StatCard(label: 'Member Aktif', value: s.activeMembers.toString(), color: const Color(0xFF60A5FA)),
                    _StatCard(label: 'Check-in', value: s.dailyCheckIns.toString(), color: const Color(0xFF4ADE80)),
                    _StatCard(label: 'Expenses', value: formatCurrency(s.expenses), color: const Color(0xFFF87171), small: true),
                  ],
                ),
              ),
            ),

            // Quick Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Quick Actions', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _ActionCard(
                    label: 'Add Member', icon: Icons.person_add_rounded, accent: true,
                    onTap: () => context.push(AppRoutes.addMember),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _ActionCard(
                    label: 'Check In', icon: Icons.qr_code_scanner_rounded, accent: false,
                    onTap: () => context.go(AppRoutes.checkin),
                  )),
                ]),
              ]),
            ),
            const SizedBox(height: 24),

            // Recent Check-ins
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Recent Activity', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                  TextButton(onPressed: () => context.go(AppRoutes.checkin),
                      child: const Text('View All', style: TextStyle(color: AppColors.accent, fontSize: 12))),
                ]),
                const SizedBox(height: 8),
                checkInsAsync.when(
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))),
                  error: (e, _) => _ErrorCard(message: ErrorHandler.parse(e)),
                  data: (records) => _CheckInList(records: records),
                ),
              ]),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showGymSwitcherBottomSheet(BuildContext context, WidgetRef ref, List<GymSimple> gyms, int? activeGymId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
                    const Text(
                      'Pilih Gym',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: gyms.length,
                    itemBuilder: (context, index) {
                      final gym = gyms[index];
                      final active = gym.id == activeGymId;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        title: Text(
                          gym.name,
                          style: TextStyle(
                            color: active ? AppColors.accent : AppColors.textPrimary,
                            fontWeight: active ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: active
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.accent)
                            : null,
                        onTap: () {
                          ref.read(authProvider.notifier).setActiveGym(gym.id);
                          Navigator.pop(context);
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
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color, this.small = false});
  final String label;
  final String value;
  final Color color;
  final bool small;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10), // Reduced from 14
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.bar_chart_rounded, color: color, size: 18)),
        Flexible( // Changed from Expanded to Flexible
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: small ? 14 : 20))),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.label, required this.icon, required this.accent, required this.onTap});
  final String label;
  final IconData icon;
  final bool accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(
              color: accent ? AppColors.accent : AppColors.surface, borderRadius: BorderRadius.circular(22)),
              child: Icon(icon, color: accent ? Colors.black : AppColors.textPrimary, size: 20)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _StatsGridSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.3,
      children: List.generate(4, (_) => Container(decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)))),
    );
  }
}

class _CheckInList extends StatelessWidget {
  const _CheckInList({required this.records});
  final List<CheckInRecord> records;
  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: const Center(child: Text('Belum ada check-in hari ini', style: TextStyle(color: AppColors.textMuted))),
      );
    }
    return Container(
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: ListView.separated(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        itemCount: records.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
        itemBuilder: (_, i) {
          final r = records[i];
          return ListTile(dense: true,
            leading: CircleAvatar(backgroundColor: AppColors.accent.withAlpha(30),
                child: Text(r.memberName[0].toUpperCase(), style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700))),
            title: Text('${r.memberName} check-in', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
            subtitle: Text(formatDateTime(r.checkedInAt), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          );
        },
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.error.withAlpha(25), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.error.withAlpha(75))),
      child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 13)),
    );
  }
}
