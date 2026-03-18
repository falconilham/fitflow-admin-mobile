import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/drawer_menu_button.dart';

final _transactionsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return [];
  try {
    return await ref.read(apiRepositoryProvider).getTransactions(gymId);
  } on DioException catch (e) {
    if (e.response?.statusCode == 403 || e.response?.statusCode == 404) return [];
    rethrow;
  }
});

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(_transactionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Transactions', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
        error: (e, _) => _ErrorWidget(e.toString()),
        data: (list) {
          if (list.isEmpty) return const _EmptyWidget('No transactions yet.');
          return RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.card,
            onRefresh: () async => ref.invalidate(_transactionsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final tx = list[i];
                final amount = (tx['amount'] ?? tx['totalAmount'] ?? tx['total_amount'] ?? 0) as num;
                final status = tx['status'] as String? ?? 'completed';
                final method = tx['paymentMethod'] ?? tx['payment_method'] ?? '-';
                final memberName = tx['memberName'] ?? tx['member_name'] ?? tx['member']?['name'];
                final date = tx['createdAt'] ?? tx['created_at'];
                final dateStr = date != null ? formatDateTime(date.toString()) : '-';

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('#${tx['id']}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                      _StatusChip(status),
                    ]),
                    const SizedBox(height: 8),
                    Text(dateStr, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 4),
                    if (memberName != null)
                      Text(memberName.toString(), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(formatCurrency(amount.toDouble()),
                          style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800, fontSize: 16)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(method.toString(), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ),
                    ]),
                  ]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);
  @override
  Widget build(BuildContext context) {
    final isCompleted = status == 'completed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFF4ADE80).withAlpha(40) : const Color(0xFFF87171).withAlpha(40),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status,
          style: TextStyle(
            color: isCompleted ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
            fontSize: 11, fontWeight: FontWeight.w700,
          )),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String msg;
  const _ErrorWidget(this.msg);
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(msg, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
    ),
  );
}

class _EmptyWidget extends StatelessWidget {
  final String msg;
  const _EmptyWidget(this.msg);
  @override
  Widget build(BuildContext context) => Center(
    child: Text(msg, style: const TextStyle(color: AppColors.textMuted)),
  );
}
