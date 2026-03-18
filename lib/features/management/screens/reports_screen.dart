import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/drawer_menu_button.dart';

final _reportsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return {};
  try {
    return await ref.read(apiRepositoryProvider).getPeakHours(gymId);
  } on DioException catch (e) {
    if (e.response?.statusCode == 403 || e.response?.statusCode == 404) return {};
    rethrow;
  }
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repAsync = ref.watch(_reportsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Reports', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
            onPressed: () => ref.invalidate(_reportsProvider),
          ),
        ],
      ),
      body: repAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
        error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.error))),
        data: (data) {
          // Parse hourCounts array (24 values, one per hour)
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
            onRefresh: () async => ref.invalidate(_reportsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header
                const Text('Reports', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 22)),
                const SizedBox(height: 4),
                const Text('Gym check-in analytics', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(height: 20),

                // Stat Cards Row
                Row(children: [
                  Expanded(child: _StatCard(
                    icon: Icons.access_time_rounded,
                    iconColor: AppColors.accent,
                    iconBg: AppColors.accent.withAlpha(30),
                    label: 'BUSIEST HOUR',
                    value: busiestHour >= 0 ? '$busiestHour:00' : '-',
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(
                    icon: Icons.people_rounded,
                    iconColor: const Color(0xFF60A5FA),
                    iconBg: const Color(0xFF60A5FA).withAlpha(30),
                    label: 'TOTAL VISITS (7 DAYS)',
                    value: totalVisits.toString(),
                  )),
                ]),
                const SizedBox(height: 20),

                // Peak Hours Chart
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Peak Hours', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text('Check-in distribution by hour of day', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 20),
                    if (hourCounts.every((c) => c == 0))
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Text('No check-in data available', style: TextStyle(color: AppColors.textMuted)),
                        ),
                      )
                    else
                      _PeakHoursChart(hourCounts: hourCounts, maxVal: maxVal, busiestHour: busiestHour),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
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
  const _StatCard({required this.icon, required this.iconColor, required this.iconBg, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border),
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 22)),
      ])),
    ]),
  );
}

// ─── Peak Hours Bar Chart ─────────────────────────────────────────────────────
class _PeakHoursChart extends StatelessWidget {
  final List<int> hourCounts;
  final int maxVal;
  final int busiestHour;
  const _PeakHoursChart({required this.hourCounts, required this.maxVal, required this.busiestHour});

  @override
  Widget build(BuildContext context) {
    const chartHeight = 180.0;
    const barSpacing = 3.0;

    return Column(children: [
      SizedBox(
        height: chartHeight,
        child: LayoutBuilder(builder: (ctx, constraints) {
          final totalWidth = constraints.maxWidth;
          final barWidth = (totalWidth - barSpacing * (hourCounts.length - 1)) / hourCounts.length;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(hourCounts.length, (i) {
              final count = hourCounts[i];
              final barHeightFrac = maxVal > 0 ? count / maxVal : 0.0;
              final barHeight = (barHeightFrac * (chartHeight - 20)).clamp(2.0, chartHeight - 20);
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
      // X-axis labels — show every 4 hours
      Row(
        children: List.generate(hourCounts.length, (i) {
          final show = i % 4 == 0;
          return Expanded(child: Text(
            show ? '${i}h' : '',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
            textAlign: TextAlign.center,
          ));
        }),
      ),
      const SizedBox(height: 12),
      // Legend
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        const Text('Busiest hour', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(width: 16),
        Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFF4B5563), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        const Text('Other hours', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ]),
    ]);
  }
}
