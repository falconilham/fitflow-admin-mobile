import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/drawer_menu_button.dart';

final _revenueProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return {};
  try {
    return await ref.read(apiRepositoryProvider).getRevenueAnalytics(gymId);
  } on DioException catch (e) {
    if (e.response?.statusCode == 403 || e.response?.statusCode == 404) return {};
    rethrow;
  }
});

class RevenueScreen extends ConsumerWidget {
  const RevenueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revAsync = ref.watch(_revenueProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Revenue Analytics', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: revAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
        error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.error))),
        data: (data) {
          if (data.isEmpty) {
            return const Center(child: Text('No revenue data available.', style: TextStyle(color: AppColors.textMuted)));
          }
          final total = (data['totalRevenue'] ?? data['total_revenue'] ?? data['total'] ?? 0) as num;
          final monthly = (data['monthlyRevenue'] ?? data['monthly_revenue'] ?? data['thisMonth'] ?? 0) as num;
          final daily = (data['dailyRevenue'] ?? data['daily_revenue'] ?? data['today'] ?? 0) as num;
          final txCount = (data['transactionCount'] ?? data['transaction_count'] ?? data['count'] ?? 0) as num;

          return RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.card,
            onRefresh: () async => ref.invalidate(_revenueProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _RevenueCard(title: 'Total Revenue', value: formatCurrency(total.toDouble()),
                    color: AppColors.accent, icon: Icons.trending_up_rounded),
                const SizedBox(height: 12),
                _RevenueCard(title: 'This Month', value: formatCurrency(monthly.toDouble()),
                    color: const Color(0xFF60A5FA), icon: Icons.calendar_month_rounded),
                const SizedBox(height: 12),
                _RevenueCard(title: 'Today', value: formatCurrency(daily.toDouble()),
                    color: const Color(0xFF4ADE80), icon: Icons.today_rounded),
                const SizedBox(height: 12),
                _RevenueCard(title: 'Total Transactions', value: txCount.toString(),
                    color: const Color(0xFFA78BFA), icon: Icons.receipt_long_rounded),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _RevenueCard({required this.title, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 22)),
        ]),
      ]),
    );
  }
}
