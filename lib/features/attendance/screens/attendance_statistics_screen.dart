import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/error_handler.dart';
import '../providers/attendance_providers.dart';

class AttendanceStatisticsScreen extends ConsumerWidget {
  const AttendanceStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(attendanceStatsProvider);
    final staffAsync = ref.watch(staffListProvider);
    final filters = ref.watch(attendanceStatsFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Stats'),
        backgroundColor: AppColors.surface,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Row(
              children: [
                Expanded(
                  child: staffAsync.when(
                    data: (staff) {
                      return DropdownButtonFormField<String?>(
                        decoration: const InputDecoration(
                          labelText: 'Filter by Staff',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        dropdownColor: AppColors.card,
                        value: filters['staffId'] as String?,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Staff', style: TextStyle(color: AppColors.textPrimary))),
                          ...staff.map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.name, style: const TextStyle(color: AppColors.textPrimary)),
                              )),
                        ],
                        onChanged: (val) {
                          ref.read(attendanceStatsFilterProvider.notifier).update((state) => {...state, 'staffId': val});
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const Text('Error loading staff'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: statsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
              error: (e, _) => Center(child: Text(ErrorHandler.parse(e), style: const TextStyle(color: AppColors.error))),
              data: (stats) {
                if (stats == null) return const Center(child: Text('No data'));

                return RefreshIndicator(
                  color: AppColors.accent,
                  backgroundColor: AppColors.card,
                  onRefresh: () async => ref.refresh(attendanceStatsProvider.future),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSummaryCards(stats.totalCheckIns, stats.onTimeCount, stats.lateCount),
                      const SizedBox(height: 24),
                      if (stats.pieChartData.isNotEmpty) ...[
                        const Text('Punctuality', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: stats.pieChartData.map((data) {
                                final color = _parseColor(data.color);
                                return PieChartSectionData(
                                  color: color,
                                  value: data.value.toDouble(),
                                  title: '${data.name}\n${data.value}',
                                  radius: 50,
                                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      if (stats.lineChartData.isNotEmpty) ...[
                        const Text('Daily Check-ins', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 220,
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (value) => FlLine(color: AppColors.border, strokeWidth: 1),
                              ),
                              titlesData: FlTitlesData(
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final index = value.toInt();
                                      if (index < 0 || index >= stats.lineChartData.length) return const SizedBox();
                                      final dateStr = stats.lineChartData[index].date;
                                      // Only show day (e.g. 26) or short string depending on length
                                      final label = dateStr.length >= 10 ? dateStr.substring(5, 10) : dateStr;
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                      );
                                    },
                                    reservedSize: 30,
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 30,
                                    getTitlesWidget: (value, meta) {
                                      return Text(value.toInt().toString(), style: const TextStyle(color: AppColors.textMuted, fontSize: 10));
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: stats.lineChartData.asMap().entries.map((e) {
                                    return FlSpot(e.key.toDouble(), e.value.checkIns.toDouble());
                                  }).toList(),
                                  isCurved: true,
                                  color: AppColors.accent,
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: true),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: AppColors.accent.withOpacity(0.2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(int total, int onTime, int late) {
    return Row(
      children: [
        Expanded(child: _StatCard(title: 'Total', value: total.toString(), color: AppColors.accent)),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(title: 'On Time', value: onTime.toString(), color: AppColors.success)),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(title: 'Late', value: late.toString(), color: AppColors.error)),
      ],
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
