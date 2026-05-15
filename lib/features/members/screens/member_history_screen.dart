import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/utils/error_handler.dart';

final _memberHistoryProvider =
    FutureProvider.autoDispose.family<List<SessionLog>, int>((ref, memberId) async {
  return ref.read(apiRepositoryProvider).getMemberSessionHistory(memberId);
});

class MemberHistoryScreen extends ConsumerWidget {
  const MemberHistoryScreen({super.key, required this.memberId});
  final int memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(_memberHistoryProvider(memberId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Histori Kunjungan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
            onPressed: () => ref.invalidate(_memberHistoryProvider(memberId)),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.card,
        onRefresh: () async => ref.invalidate(_memberHistoryProvider(memberId)),
        child: logsAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 120),
              Center(
                child: Text(ErrorHandler.parse(e),
                    style: const TextStyle(color: AppColors.error)),
              ),
            ],
          ),
          data: (logs) {
            if (logs.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.history_toggle_off_rounded,
                            size: 56, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Text(
                          'Belum ada histori kunjungan',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final totalMinutes = logs.fold<int>(0, (a, b) => a + b.duration);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SummaryTile(
                          label: 'Total Visit',
                          value: '${logs.length}',
                          color: AppColors.accent,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: AppColors.border,
                      ),
                      Expanded(
                        child: _SummaryTile(
                          label: 'Total Menit',
                          value: '$totalMinutes',
                          color: const Color(0xFF60A5FA),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...logs.map((log) => _LogTile(log: log)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 22)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _LogTile extends StatelessWidget {
  final SessionLog log;
  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.fitness_center_rounded,
                size: 18, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${log.duration} menit',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatDateTime(log.timestamp),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                if (log.packageName != null && log.packageName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    log.packageName!,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          if (log.adminName != null && log.adminName!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                log.adminName!,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }
}
