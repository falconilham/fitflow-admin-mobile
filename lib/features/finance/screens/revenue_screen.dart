import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/drawer_menu_button.dart';
import '../../../shared/utils/error_handler.dart';

final _revenueProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return {};
  try {
    // Hit /admin/revenue with limit=1 — we only need summary + breakdown
    return await ref.read(apiRepositoryProvider).getRevenueDetails(
          gymId,
          status: 'active',
          page: 1,
          limit: 1,
        );
  } on DioException catch (e) {
    if (e.response?.statusCode == 403 || e.response?.statusCode == 404) {
      return {};
    }
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
        title: const Text('Revenue Analytics',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
            onPressed: () => ref.invalidate(_revenueProvider),
          ),
        ],
      ),
      body: revAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(ErrorHandler.parse(e),
                style: const TextStyle(color: AppColors.error),
                textAlign: TextAlign.center),
          ),
        ),
        data: (data) {
          if (data.isEmpty) {
            return const Center(
                child: Text(
              'Tidak ada akses atau data.\nButuh permission Owner / Finance.',
              style: TextStyle(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ));
          }
          final summary =
              (data['summary'] as Map?)?.cast<String, dynamic>() ?? {};
          final breakdown =
              (data['breakdown'] as List?)?.cast<dynamic>() ?? const [];
          final pagination =
              (data['pagination'] as Map?)?.cast<String, dynamic>() ?? {};

          final grossProfit = ((summary['gross_profit'] ?? 0) as num).toDouble();
          final expenses = ((summary['expenses'] ?? 0) as num).toDouble();
          final netProfit = ((summary['net_profit'] ?? 0) as num).toDouble();
          final netCash = ((summary['net_cash'] ?? 0) as num).toDouble();
          final netAccount = ((summary['net_account'] ?? 0) as num).toDouble();
          final totalItems =
              (pagination['totalItems'] as num?)?.toInt() ?? 0;

          return RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.card,
            onRefresh: () async => ref.invalidate(_revenueProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _RevenueCard(
                  title: 'Gross Profit',
                  value: formatCurrency(grossProfit),
                  color: const Color(0xFF3B82F6),
                  icon: Icons.trending_up_rounded,
                ),
                const SizedBox(height: 10),
                _RevenueCard(
                  title: 'Total Expenses',
                  value: formatCurrency(expenses),
                  color: AppColors.error,
                  icon: Icons.trending_down_rounded,
                ),
                const SizedBox(height: 10),
                _RevenueCard(
                  title: 'Net Profit',
                  value: formatCurrency(netProfit),
                  color: netProfit >= 0 ? AppColors.success : AppColors.error,
                  icon: Icons.account_balance_rounded,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _RevenueCard(
                        title: 'Net Cash',
                        value: formatCurrency(netCash),
                        color: AppColors.success,
                        icon: Icons.payments_rounded,
                        dense: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RevenueCard(
                        title: 'Net Account',
                        value: formatCurrency(netAccount),
                        color: const Color(0xFFFBBF24),
                        icon: Icons.credit_card_rounded,
                        dense: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _RevenueCard(
                  title: 'Total Transactions',
                  value: totalItems.toString(),
                  color: const Color(0xFFA78BFA),
                  icon: Icons.receipt_long_rounded,
                ),
                const SizedBox(height: 20),
                // Breakdown by type
                if (breakdown.isNotEmpty) _Breakdown(breakdown: breakdown),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  final List<dynamic> breakdown;
  const _Breakdown({required this.breakdown});

  String _label(String type) {
    switch (type) {
      case 'MEMBERSHIP_NEW':
        return 'Membership Baru';
      case 'MEMBERSHIP_EXTENSION':
        return 'Perpanjangan';
      case 'SESSION_BOOKING':
        return 'PT Session';
      case 'PACKAGE_PURCHASE':
        return 'Paket Trainer';
      case 'OTHER':
        return 'POS / Penjualan';
      default:
        return type;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'MEMBERSHIP_NEW':
        return const Color(0xFF4ADE80);
      case 'MEMBERSHIP_EXTENSION':
        return const Color(0xFF60A5FA);
      case 'SESSION_BOOKING':
        return const Color(0xFFF472B6);
      case 'PACKAGE_PURCHASE':
        return const Color(0xFFC084FC);
      default:
        return const Color(0xFFFBBF24);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = breakdown
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    final total = items.fold<double>(0, (sum, it) {
      final v = it['total'];
      if (v is num) return sum + v.toDouble();
      return sum + (double.tryParse(v?.toString() ?? '') ?? 0);
    });

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
          const Text('Distribusi Pendapatan',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15)),
          const SizedBox(height: 12),
          ...items.map((it) {
            final type = (it['type'] as String?) ?? '';
            final rawTotal = it['total'];
            final amount = rawTotal is num
                ? rawTotal.toDouble()
                : double.tryParse(rawTotal?.toString() ?? '') ?? 0;
            final rawCount = it['count'];
            final count = rawCount is num
                ? rawCount.toInt()
                : int.tryParse(rawCount?.toString() ?? '') ?? 0;
            final pct = total > 0 ? (amount / total) * 100 : 0;
            final color = _color(type);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: color, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_label(type),
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600))),
                      Text(formatCurrency(amount),
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      const SizedBox(width: 8),
                      SizedBox(
                          width: 48,
                          child: Text(
                            '${pct.toStringAsFixed(0)}%',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11),
                          )),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    const SizedBox(width: 18),
                    Text('$count transaksi',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                  ]),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final bool dense;

  const _RevenueCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(dense ? 14 : 18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Container(
            width: dense ? 42 : 50,
            height: dense ? 42 : 50,
            decoration: BoxDecoration(
                color: color.withAlpha(30), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: dense ? 20 : 24),
          ),
          SizedBox(width: dense ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: dense ? 11 : 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4)),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: dense ? 16 : 20),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
