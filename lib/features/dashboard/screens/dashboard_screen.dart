import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/updater/app_updater_service.dart';
import '../../../data/models/models.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/utils/error_handler.dart';
import '../../../shared/utils/format.dart';
import '../providers/dashboard_providers.dart';

export '../providers/dashboard_providers.dart';

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

  String _greetingText(AppLocalizations l10n, String name) {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 11) return l10n.greetingMorning(name);
    if (hour >= 11 && hour < 15) return l10n.greetingAfternoon(name);
    if (hour >= 15 && hour < 18) return l10n.greetingEvening(name);
    return l10n.greetingNight(name);
  }

  String _firstName(String? fullName) {
    final trimmed = (fullName ?? '').trim();
    if (trimmed.isEmpty) return 'Admin';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider).valueOrNull;
    final admin = authState?.admin;
    final activeGymId = authState?.activeGymId;
    final statsAsync = ref.watch(dashboardStatsProvider);
    final checkInsAsync = ref.watch(recentCheckInsProvider);
    final gyms = ref.watch(myGymsProvider).valueOrNull ?? const <GymSimple>[];
    final activeFeatures = AccessControl.resolveActiveFeatures(
      admin: admin,
      gyms: gyms,
      activeGymId: activeGymId,
    );

    bool allow(String feature) => AccessControl.canAccess(
          admin: admin,
          gymFeatures: activeFeatures,
          feature: feature,
        );

    final quickActions = <Widget>[
      if (allow('check_in'))
        Expanded(
          child: _QuickAccessTile(
            icon: LucideIcons.qrCode,
            label: l10n.quickCheckIn,
            onTap: () => context.go(AppRoutes.checkin),
          ),
        ),
      if (allow('members'))
        Expanded(
          child: _QuickAccessTile(
            icon: LucideIcons.users,
            label: l10n.quickMember,
            onTap: () => context.go(AppRoutes.members),
          ),
        ),
      if (allow('pos'))
        Expanded(
          child: _QuickAccessTile(
            icon: LucideIcons.monitor,
            label: l10n.quickPos,
            onTap: () => context.push(AppRoutes.pos),
          ),
        ),
      if (allow('sessions'))
        Expanded(
          child: _QuickAccessTile(
            icon: LucideIcons.calendarDays,
            label: l10n.menuSessions,
            onTap: () => context.push(AppRoutes.sessions),
          ),
        ),
    ];

    ref.listen(myGymsProvider, (_, next) {
      next.whenData((gyms) {
        if (activeGymId == null && gyms.isNotEmpty) {
          ref.read(authProvider.notifier).setActiveGym(gyms.first.id);
        }
      });
    });

    final localeTag = Localizations.localeOf(context).languageCode == 'en'
        ? 'en_US'
        : 'id_ID';
    final formattedDate =
        DateFormat('EEEE, d MMMM yyyy', localeTag).format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.card,
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(recentCheckInsProvider);
          ref.invalidate(myGymsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
                  // ── Greeting & Title Header ──────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greetingText(l10n, _firstName(admin?.name)),
                              style: GoogleFonts.figtree(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.summaryTitle,
                              style: GoogleFonts.figtree(
                                color: AppColors.textPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formattedDate,
                              style: GoogleFonts.figtree(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        margin: const EdgeInsets.only(top: 18),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(
                          l10n.todayChip,
                          style: GoogleFonts.figtree(
                            color: AppColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Primary KPI Row ──────────────────────────────────────
                  statsAsync.when(
                    loading: () => const _KpiSkeletonRow(),
                    error: (e, _) => _ErrorBanner(message: ErrorHandler.parse(e)),
                    data: (s) => Row(
                      children: [
                        Expanded(
                          child: _SummaryKpiCard(
                            title: l10n.checkInTodayLabel,
                            value: s.dailyCheckIns.toString(),
                            subtitle: l10n.qrManualBreakdown(
                              s.qrCheckIns,
                              s.manualCheckIns,
                            ),
                            icon: LucideIcons.qrCode,
                            onTap: () => context.go(AppRoutes.checkin),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryKpiCard(
                            title: l10n.insideGymLabel,
                            value: s.currentlyInside.toString(),
                            subtitle: l10n.membersTrainingLabel,
                            icon: LucideIcons.users,
                            onTap: () => context.go(AppRoutes.members),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Akses cepat ──────────────────────────────────────────
                  if (quickActions.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.quickAccessTitle,
                          style: GoogleFonts.figtree(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        InkWell(
                          onTap: () => context.push(AppRoutes.allMenu),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Text(
                              l10n.allMenuAction,
                              style: GoogleFonts.figtree(
                                color: AppColors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        for (int i = 0; i < quickActions.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          quickActions[i],
                        ],
                      ],
                    ),
                    const SizedBox(height: 22),
                  ],

                  // ── Kehadiran hari ini Card ──────────────────────────────
                  statsAsync.maybeWhen(
                    data: (s) => _AttendanceChartCard(
                      title: l10n.todayAttendanceTitle,
                      subtitle: l10n.checkInCountLabel(s.dailyCheckIns),
                      liveLabel: l10n.liveBadge,
                      hourlyCounts: s.todayHourlyCheckIns,
                    ),
                    orElse: () => _AttendanceChartCard(
                      title: l10n.todayAttendanceTitle,
                      subtitle: l10n.checkInCountLabel(0),
                      liveLabel: l10n.liveBadge,
                      hourlyCounts: const [],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Check-in terbaru ─────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.recentCheckInsTitle,
                        style: GoogleFonts.figtree(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      InkWell(
                        onTap: () => context.go(AppRoutes.checkin),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Text(
                            l10n.seeAllAction,
                            style: GoogleFonts.figtree(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  checkInsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    error: (e, _) =>
                        _ErrorBanner(message: ErrorHandler.parse(e)),
                    data: (records) {
                      if (records.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          alignment: Alignment.center,
                          child: Text(
                            l10n.noCheckInsToday,
                            style: GoogleFonts.figtree(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: List.generate(records.length, (i) {
                          final r = records[i];
                          return Column(
                            children: [
                              _RecentCheckInRow(record: r),
                              if (i < records.length - 1)
                                const Padding(
                                  padding: EdgeInsets.only(left: 34),
                                  child: Divider(
                                    height: 1,
                                    color: AppColors.border,
                                  ),
                                ),
                            ],
                          );
                        }),
                      );
                    },
                  ),
                ],
        ),
      ),
    );
  }
}

class _SummaryKpiCard extends StatelessWidget {
  const _SummaryKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 108,
        padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: GoogleFonts.figtree(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(icon, size: 20, color: AppColors.accent),
              ],
            ),
            Text(
              value,
              style: GoogleFonts.figtree(
                color: AppColors.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w600,
                height: 1.05,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.figtree(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w400,
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

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.iconSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 22,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.figtree(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceChartCard extends StatelessWidget {
  const _AttendanceChartCard({
    required this.title,
    required this.subtitle,
    required this.liveLabel,
    required this.hourlyCounts,
  });

  final String title;
  final String subtitle;
  final String liveLabel;
  final List<int> hourlyCounts;

  @override
  Widget build(BuildContext context) {
    // 12 hourly buckets from 06:00 to 17:00 (covering the 06.00 – 18.00 window)
    const startHour = 6;
    const barCount = 12;
    final values = List<int>.generate(barCount, (i) {
      final h = startHour + i;
      return h < hourlyCounts.length ? hourlyCounts[h] : 0;
    });
    final maxVal = values.fold<int>(0, math.max);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.figtree(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.figtree(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.successPillBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  liveLabel,
                  style: GoogleFonts.figtree(
                    color: AppColors.successPillText,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 60,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(barCount, (i) {
                final v = values[i];
                final isPeak = maxVal > 0 && v == maxVal;
                final barHeight = maxVal > 0
                    ? math.max(8.0, (v / maxVal) * 58.0)
                    : 10.0;
                return Container(
                  width: 16,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: isPeak ? AppColors.accent : AppColors.chartBarMuted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '06.00',
                style: GoogleFonts.figtree(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
              Text(
                '12.00',
                style: GoogleFonts.figtree(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
              Text(
                '18.00',
                style: GoogleFonts.figtree(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentCheckInRow extends StatelessWidget {
  const _RecentCheckInRow({required this.record});

  final CheckInRecord record;

  @override
  Widget build(BuildContext context) {
    final pkgLabel = (record.packageName ?? '').trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          const Icon(
            LucideIcons.check,
            size: 18,
            color: AppColors.accent,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.memberName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.figtree(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (pkgLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    pkgLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.figtree(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatTime(record.checkedInAt),
            style: GoogleFonts.figtree(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiSkeletonRow extends StatelessWidget {
  const _KpiSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 108,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 108,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
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
              style: GoogleFonts.figtree(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
