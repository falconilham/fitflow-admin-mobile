import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/updater/app_updater_service.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/drawer_menu_button.dart';
import '../../../shared/utils/error_handler.dart';
import '../../notifications/providers/notifications_provider.dart';

// ── Providers ──────────────────────────────────────────────────────────────

final myGymsProvider = FutureProvider.autoDispose<List<GymSimple>>((ref) async {
  return ref.read(apiRepositoryProvider).getMyGyms();
});

final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((ref) async {
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

final expiringMembersProvider = FutureProvider.autoDispose<List<ExpiringMember>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return <ExpiringMember>[];
  return ref.read(apiRepositoryProvider).getExpiringMembers(gymId, limit: 5);
});

final recentCheckInsProvider = FutureProvider.autoDispose<List<CheckInRecord>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return <CheckInRecord>[];
  return ref.read(apiRepositoryProvider).getRecentCheckIns(gymId, limit: 5);
});

// ── Screen ──────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppUpdaterService.checkForUpdates(context);
      }
    });
  }

  Future<void> _launchWhatsApp(String phone, String memberName, String endDate, int daysLeft, String gymName) async {
    if (phone.isEmpty) return;
    var cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62${cleanPhone.substring(1)}';
    }
    final message = Uri.encodeComponent(
      'Halo $memberName! Membership Anda di $gymName akan berakhir pada $endDate ($daysLeft hari lagi). '
      'Yuk perpanjang sekarang agar Anda tetap bisa berolahraga tanpa jeda!',
    );
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).valueOrNull;
    final admin = authState?.admin;
    final activeGymId = authState?.activeGymId;
    final isOwner = admin?.role == 'owner';
    final statsAsync = ref.watch(dashboardStatsProvider);
    final expiringAsync = ref.watch(expiringMembersProvider);
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
                  style: GoogleFonts.outfit(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
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
          Consumer(
            builder: (context, ref, _) {
              final unreadCount = ref.watch(unreadNotificationsCountProvider);
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      unreadCount > 0
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                      color: unreadCount > 0 ? AppColors.accent : AppColors.textMuted,
                    ),
                    onPressed: () => context.push(AppRoutes.notifications),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.surface, width: 1.5),
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.card,
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(expiringMembersProvider);
          ref.invalidate(recentCheckInsProvider);
          ref.invalidate(myGymsProvider);
          ref.invalidate(notificationsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // ── Dashboard Welcome Header (Matching Web Dashboard) ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dashboard',
                            style: GoogleFonts.outfit(
                              color: AppColors.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Selamat datang kembali, ${admin?.name ?? 'Admin'}',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Gym Subscription Expiry Pill Badge (matching web top right)
                    statsAsync.maybeWhen(
                      data: (s) {
                        if (s.gymExpiryDate == null) return const SizedBox.shrink();
                        DateTime? expiry;
                        try {
                          expiry = DateTime.parse(s.gymExpiryDate!);
                        } catch (_) {
                          return const SizedBox.shrink();
                        }
                        final now = DateTime.now();
                        final daysLeft = expiry.difference(DateTime(now.year, now.month, now.day)).inDays;
                        final isExpired = daysLeft < 0;
                        final isWarning = !isExpired && daysLeft <= 14;
                        final color = isExpired ? AppColors.error : isWarning ? AppColors.warning : AppColors.success;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withAlpha(25),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: color.withAlpha(80)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.clock, size: 12, color: color),
                              const SizedBox(width: 5),
                              Text(
                                isExpired ? 'Kedaluwarsa' : '$daysLeft Hari Lagi',
                                style: GoogleFonts.outfit(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── KPI Cards Grid (Matching Web Admin Dashboard) ──
            statsAsync.when(
              loading: () => _StatsGridSkeleton(),
              error: (e, _) => _ErrorCard(message: ErrorHandler.parse(e)),
              data: (s) => Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _WebKPICard(
                          title: 'TOTAL ANGGOTA',
                          value: s.totalMembers.toString(),
                          subtext: 'Aktif: ${s.activeMembers} • Habis: ${s.expiredMembers}',
                          icon: LucideIcons.users,
                          color: AppColors.accent,
                          onTap: () => context.push(AppRoutes.members),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _WebKPICard(
                          title: 'CHECK-IN HARIAN',
                          value: s.dailyCheckIns.toString(),
                          subtext: 'Hari Ini',
                          icon: LucideIcons.activity,
                          color: const Color(0xFF4ADE80),
                          onTap: () => context.push(AppRoutes.checkin),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _WebKPICard(
                          title: 'TOTAL OMZET',
                          badge: isOwner ? 'KHUSUS OWNER' : null,
                          value: formatCurrency(s.revenue),
                          subtext: 'Bulan Ini',
                          icon: LucideIcons.wallet,
                          color: const Color(0xFF60A5FA),
                          onTap: () => context.push(AppRoutes.revenue),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _WebKPICard(
                          title: 'PENGELUARAN',
                          value: formatCurrency(s.expenses),
                          subtext: 'Bulan Ini',
                          icon: LucideIcons.receipt,
                          color: const Color(0xFFF87171),
                          onTap: () => context.push(AppRoutes.expenses),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Quick Actions ──
            Row(
              children: [
                Expanded(
                  child: _ActionChip(
                    label: 'Check-In',
                    icon: LucideIcons.qrCode,
                    accent: true,
                    onTap: () => context.push(AppRoutes.checkin),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionChip(
                    label: 'Member',
                    icon: LucideIcons.userPlus,
                    accent: false,
                    onTap: () => context.push(AppRoutes.addMember),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionChip(
                    label: 'POS Kasir',
                    icon: LucideIcons.shoppingBag,
                    accent: false,
                    onTap: () => context.push(AppRoutes.pos),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionChip(
                    label: 'Biaya',
                    icon: LucideIcons.plusCircle,
                    accent: false,
                    onTap: () => context.push(AppRoutes.expenses),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Anggota Segera Habis (Expiring Members) matching Web Dashboard ──
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF87171).withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(LucideIcons.clock, size: 16, color: Color(0xFFF87171)),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Anggota Segera Habis',
                              style: GoogleFonts.outfit(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => context.push(AppRoutes.members),
                          child: Row(
                            children: [
                              Text(
                                'LIHAT SEMUA',
                                style: GoogleFonts.outfit(
                                  color: AppColors.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(LucideIcons.arrowUpRight, size: 13, color: AppColors.accent),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  expiringAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(ErrorHandler.parse(e), style: const TextStyle(color: AppColors.error, fontSize: 12)),
                    ),
                    data: (members) {
                      if (members.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'Tidak ada member yang akan habis dalam 7 hari',
                              style: GoogleFonts.plusJakartaSans(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: members.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (context, i) {
                          final m = members[i];
                          final isCritical = m.daysLeft <= 3;
                          final badgeColor = isCritical ? const Color(0xFFF87171) : const Color(0xFFFBBF24);

                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.surface,
                              child: Text(
                                m.name.isNotEmpty ? m.name[0].toUpperCase() : 'M',
                                style: GoogleFonts.outfit(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            title: Text(
                              m.name,
                              style: GoogleFonts.outfit(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'Ends: ${m.endDate}',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withAlpha(25),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: badgeColor.withAlpha(60)),
                                  ),
                                  child: Text(
                                    '${m.daysLeft} Hari',
                                    style: GoogleFonts.outfit(
                                      color: badgeColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (m.phone.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => _launchWhatsApp(m.phone, m.name, m.endDate, m.daysLeft, activeGymName),
                                    child: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF25D366).withAlpha(25),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFF25D366).withAlpha(80)),
                                      ),
                                      child: const Icon(
                                        LucideIcons.messageSquare,
                                        size: 15,
                                        color: Color(0xFF25D366),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Check-in Terbaru matching Web Dashboard ──
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4ADE80).withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(LucideIcons.activity, size: 16, color: Color(0xFF4ADE80)),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Check-in Terbaru',
                              style: GoogleFonts.outfit(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => context.push(AppRoutes.checkin),
                          child: Row(
                            children: [
                              Text(
                                'LIHAT SEMUA',
                                style: GoogleFonts.outfit(
                                  color: AppColors.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(LucideIcons.arrowUpRight, size: 13, color: AppColors.accent),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  checkInsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(ErrorHandler.parse(e), style: const TextStyle(color: AppColors.error, fontSize: 12)),
                    ),
                    data: (records) {
                      if (records.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'Belum ada check-in hari ini',
                              style: GoogleFonts.plusJakartaSans(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: records.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (context, i) {
                          final r = records[i];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.accent.withAlpha(25),
                              child: Text(
                                r.memberName.isNotEmpty ? r.memberName[0].toUpperCase() : 'M',
                                style: GoogleFonts.outfit(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            title: Text(
                              r.memberName,
                              style: GoogleFonts.outfit(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              formatDateTime(r.checkedInAt),
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4ADE80).withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF4ADE80).withAlpha(60)),
                              ),
                              child: Text(
                                'GRANTED',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF4ADE80),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),
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
                    Text(
                      'Pilih Gym Cabang',
                      style: GoogleFonts.outfit(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: AppColors.textMuted),
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
                        leading: CircleAvatar(
                          backgroundColor: active ? AppColors.accent : AppColors.card,
                          child: Text(
                            gym.name.isNotEmpty ? gym.name[0].toUpperCase() : 'G',
                            style: GoogleFonts.outfit(
                              color: active ? Colors.black : AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(
                          gym.name,
                          style: GoogleFonts.outfit(
                            color: active ? AppColors.accent : AppColors.textPrimary,
                            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                        trailing: active
                            ? const Icon(LucideIcons.checkCircle2, color: AppColors.accent)
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

// ── Web-Styled KPI Card Component ──

class _WebKPICard extends StatelessWidget {
  const _WebKPICard({
    required this.title,
    required this.value,
    required this.subtext,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String value;
  final String subtext;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon Container + Optional Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withAlpha(28),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge!,
                      style: GoogleFonts.outfit(
                        color: AppColors.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Caption Title
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),

            // Main Value
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),

            // Subtext breakdown
            Text(
              subtext,
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // Bottom Right Link: LIHAT SEMUA ↗
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'LIHAT SEMUA',
                  style: GoogleFonts.outfit(
                    color: AppColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(LucideIcons.arrowUpRight, size: 12, color: AppColors.accent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: accent ? AppColors.accent.withAlpha(25) : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accent ? AppColors.accent.withAlpha(80) : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: accent ? AppColors.accent : AppColors.textPrimary,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: accent ? AppColors.accent : AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGridSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Container(height: 140, decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18)))),
            const SizedBox(width: 12),
            Expanded(child: Container(height: 140, decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18)))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Container(height: 140, decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18)))),
            const SizedBox(width: 12),
            Expanded(child: Container(height: 140, decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18)))),
          ],
        ),
      ],
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
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withAlpha(75)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertTriangle, size: 18, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.plusJakartaSans(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
