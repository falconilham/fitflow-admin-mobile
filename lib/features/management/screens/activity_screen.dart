import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/drawer_menu_button.dart';

final _activityProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return [];
  try {
    return await ref.read(apiRepositoryProvider).getActivity(gymId, limit: 100);
  } on DioException catch (e) {
    if (e.response?.statusCode == 403 || e.response?.statusCode == 404) return [];
    rethrow;
  }
});

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actAsync = ref.watch(_activityProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Activity', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
            onPressed: () => ref.invalidate(_activityProvider),
          ),
        ],
      ),
      body: actAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
        error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.error))),
        data: (list) {
          if (list.isEmpty) {
            return RefreshIndicator(
              color: AppColors.accent, backgroundColor: AppColors.card,
              onRefresh: () async => ref.invalidate(_activityProvider),
              child: ListView(children: const [
                SizedBox(height: 200),
                Center(child: Text('No activity yet.', style: TextStyle(color: AppColors.textMuted))),
              ]),
            );
          }
          return RefreshIndicator(
            color: AppColors.accent, backgroundColor: AppColors.card,
            onRefresh: () async => ref.invalidate(_activityProvider),
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: ListView.separated(
                shrinkWrap: false,
                padding: EdgeInsets.zero,
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                itemBuilder: (_, i) {
                  final a = list[i];
                  final memberName = a['memberName'] ?? a['member_name'] ?? a['member']?['name'] ?? 'Unknown';
                  final checkedIn = a['checkedInAt'] ?? a['checked_in_at'] ?? a['createdAt'] ?? a['created_at'];
                  final type = a['type'] ?? a['checkInType'] ?? 'check-in';
                  final dateStr = checkedIn != null ? formatDateTime(checkedIn.toString()) : '-';
                  final initials = memberName.toString().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase();

                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.accent.withAlpha(30),
                      child: Text(initials, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                    title: Text(memberName.toString(),
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(dateStr, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.accent.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                      child: Text(type.toString(), style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
