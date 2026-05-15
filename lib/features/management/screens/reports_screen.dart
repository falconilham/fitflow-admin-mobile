import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/drawer_menu_button.dart';
import '../../../shared/utils/error_handler.dart';

final _peakHoursProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return {};
  try {
    return await ref.read(apiRepositoryProvider).getPeakHours(gymId);
  } on DioException catch (e) {
    if (e.response?.statusCode == 403 || e.response?.statusCode == 404) {
      return {};
    }
    rethrow;
  }
});

final _investorReportProvider =
    FutureProvider.autoDispose<InvestorReport?>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return null;
  try {
    return await ref.read(apiRepositoryProvider).getInvestorReport(gymId);
  } on DioException catch (e) {
    if (e.response?.statusCode == 403 || e.response?.statusCode == 404) {
      return null;
    }
    rethrow;
  }
});

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Reports',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
            onPressed: () {
              ref.invalidate(_peakHoursProvider);
              ref.invalidate(_investorReportProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.accent,
          indicatorWeight: 2.5,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Executive'),
            Tab(text: 'Peak Hours'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _ExecutiveTab(),
          _PeakHoursTab(),
        ],
      ),
    );
  }
}

// ─── Executive / Investor Tab ────────────────────────────────────────────────
class _ExecutiveTab extends ConsumerWidget {
  const _ExecutiveTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repAsync = ref.watch(_investorReportProvider);

    return repAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            ErrorHandler.parse(e),
            style: const TextStyle(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (rep) {
        if (rep == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Akses laporan executive memerlukan permission Owner atau Finance.',
                style: TextStyle(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.card,
          onRefresh: () async => ref.invalidate(_investorReportProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header
              const Text('Ringkasan Keuangan',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
              const SizedBox(height: 4),
              Text(_periodText(rep),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 16),

              // Financial Health
              _BigStatCard(
                label: 'Net Profit',
                value: formatCurrency(rep.netProfit),
                sub: 'Margin ${rep.profitMargin.toStringAsFixed(1)}%',
                color: rep.netProfit >= 0 ? AppColors.success : AppColors.error,
                icon: Icons.trending_up_rounded,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _StatCard(
                  icon: Icons.attach_money_rounded,
                  iconColor: AppColors.accent,
                  iconBg: AppColors.accent.withAlpha(30),
                  label: 'GROSS REVENUE',
                  value: formatCurrency(rep.grossRevenue),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _StatCard(
                  icon: Icons.receipt_long_rounded,
                  iconColor: AppColors.warning,
                  iconBg: AppColors.warning.withAlpha(30),
                  label: 'EXPENSES',
                  value: formatCurrency(rep.totalExpenses),
                )),
              ]),
              const SizedBox(height: 20),

              // Revenue Distribution
              const Text('Distribusi Pendapatan',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
              const SizedBox(height: 10),
              _RevenueDistributionCard(report: rep),

              const SizedBox(height: 20),

              // Growth Metrics
              const Text('Growth Metrics',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _StatCard(
                  icon: Icons.person_add_alt_1_rounded,
                  iconColor: AppColors.success,
                  iconBg: AppColors.success.withAlpha(30),
                  label: 'NEW MEMBERS',
                  value: rep.newMembers.toString(),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _StatCard(
                  icon: Icons.people_alt_rounded,
                  iconColor: const Color(0xFF60A5FA),
                  iconBg: const Color(0xFF60A5FA).withAlpha(30),
                  label: 'ACTIVE MEMBERS',
                  value: rep.totalActiveMembers.toString(),
                )),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _StatCard(
                  icon: Icons.person_off_rounded,
                  iconColor: AppColors.error,
                  iconBg: AppColors.error.withAlpha(30),
                  label: 'CHURNED',
                  value: rep.churnedMembers.toString(),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _StatCard(
                  icon: Icons.percent_rounded,
                  iconColor: AppColors.warning,
                  iconBg: AppColors.warning.withAlpha(30),
                  label: 'CHURN RATE',
                  value: '${rep.churnRate.toStringAsFixed(1)}%',
                )),
              ]),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  String _periodText(InvestorReport r) {
    if (r.periodStart == null || r.periodEnd == null) return 'Tahun berjalan';
    return '${formatDate(r.periodStart)} — ${formatDate(r.periodEnd)}';
  }
}

class _BigStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;
  final IconData icon;
  const _BigStatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        color: color, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(sub,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueDistributionCard extends StatelessWidget {
  final InvestorReport report;
  const _RevenueDistributionCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final total = report.membershipRev + report.personalTrainingRev + report.posRev;

    final items = [
      _DistItem('Membership', report.membershipRev, AppColors.accent),
      _DistItem('Personal Training', report.personalTrainingRev, const Color(0xFF60A5FA)),
      _DistItem('POS & Retail', report.posRev, AppColors.warning),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stacked bar
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: items
                      .map((it) => Expanded(
                            flex: total > 0
                                ? ((it.amount / total) * 1000).round().clamp(1, 1000)
                                : 1,
                            child: Container(color: it.color),
                          ))
                      .toList(),
                ),
              ),
            )
          else
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          const SizedBox(height: 14),
          ...items.map((it) {
            final pct = total > 0 ? (it.amount / total) * 100 : 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: it.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      it.label,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  Text(
                    formatCurrency(it.amount),
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${pct.toStringAsFixed(0)}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DistItem {
  final String label;
  final double amount;
  final Color color;
  _DistItem(this.label, this.amount, this.color);
}

// ─── Peak Hours Tab ──────────────────────────────────────────────────────────
class _PeakHoursTab extends ConsumerWidget {
  const _PeakHoursTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repAsync = ref.watch(_peakHoursProvider);

    return repAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
      error: (e, _) => Center(
          child: Text(ErrorHandler.parse(e), style: const TextStyle(color: AppColors.error))),
      data: (data) {
        final rawCounts = data['hourCounts'];
        final List<int> hourCounts;
        if (rawCounts is List) {
          hourCounts = rawCounts.map((v) => (v as num).toInt()).toList();
        } else {
          hourCounts = List.filled(24, 0);
        }

        final maxVal = hourCounts.isEmpty ? 1 : hourCounts.reduce((a, b) => a > b ? a : b);
        final totalVisits = hourCounts.fold(0, (a, b) => a + b);
        final busiestHour = maxVal > 0 ? hourCounts.indexOf(maxVal) : -1;

        return RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.card,
          onRefresh: () async => ref.invalidate(_peakHoursProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Gym check-in analytics',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: _StatCard(
                  icon: Icons.access_time_rounded,
                  iconColor: AppColors.accent,
                  iconBg: AppColors.accent.withAlpha(30),
                  label: 'BUSIEST HOUR',
                  value: busiestHour >= 0 ? '$busiestHour:00' : '-',
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _StatCard(
                  icon: Icons.people_rounded,
                  iconColor: const Color(0xFF60A5FA),
                  iconBg: const Color(0xFF60A5FA).withAlpha(30),
                  label: 'TOTAL VISITS (7 DAYS)',
                  value: totalVisits.toString(),
                )),
              ]),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Peak Hours',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text('Check-in distribution by hour of day',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 20),
                  if (hourCounts.every((c) => c == 0))
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Text('No check-in data available',
                            style: TextStyle(color: AppColors.textMuted)),
                      ),
                    )
                  else
                    _PeakHoursChart(
                        hourCounts: hourCounts, maxVal: maxVal, busiestHour: busiestHour),
                ]),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

// ─── Stat Card ───────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  const _StatCard(
      {required this.icon,
      required this.iconColor,
      required this.iconBg,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 20),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ])),
        ]),
      );
}

// ─── Peak Hours Bar Chart ─────────────────────────────────────────────────────
class _PeakHoursChart extends StatelessWidget {
  final List<int> hourCounts;
  final int maxVal;
  final int busiestHour;
  const _PeakHoursChart(
      {required this.hourCounts, required this.maxVal, required this.busiestHour});

  @override
  Widget build(BuildContext context) {
    const chartHeight = 180.0;
    const barSpacing = 3.0;

    return Column(children: [
      SizedBox(
        height: chartHeight,
        child: LayoutBuilder(builder: (ctx, constraints) {
          final totalWidth = constraints.maxWidth;
          final barWidth =
              (totalWidth - barSpacing * (hourCounts.length - 1)) / hourCounts.length;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(hourCounts.length, (i) {
              final count = hourCounts[i];
              final barHeightFrac = maxVal > 0 ? count / maxVal : 0.0;
              final barHeight =
                  (barHeightFrac * (chartHeight - 20)).clamp(2.0, chartHeight - 20);
              final isBusiest = i == busiestHour;

              return Padding(
                padding: EdgeInsets.only(right: i < hourCounts.length - 1 ? barSpacing : 0),
                child: Tooltip(
                  message: '$i:00 — $count visits',
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300 + i * 10),
                    curve: Curves.easeOut,
                    width: barWidth,
                    height: count == 0 ? 2 : barHeight,
                    decoration: BoxDecoration(
                      color: isBusiest ? AppColors.accent : const Color(0xFF4B5563),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ),
      const SizedBox(height: 8),
      Row(
        children: List.generate(hourCounts.length, (i) {
          final show = i % 4 == 0;
          return Expanded(
              child: Text(
            show ? '${i}h' : '',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
            textAlign: TextAlign.center,
          ));
        }),
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            width: 12,
            height: 12,
            decoration:
                BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        const Text('Busiest hour', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(width: 16),
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: const Color(0xFF4B5563), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        const Text('Other hours', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ]),
    ]);
  }
}
