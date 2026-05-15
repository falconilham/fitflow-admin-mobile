import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/drawer_menu_button.dart';
import '../../../shared/utils/error_handler.dart';

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
        error: (e, _) => Center(child: Text(ErrorHandler.parse(e), style: const TextStyle(color: AppColors.error))),
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
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final a = list[i];
                final action = a['action']?.toString() ?? 'CHECK_IN';
                final detailsStr = a['details']?.toString() ?? '{}';
                Map<String, dynamic> det = {};
                try {
                  det = jsonDecode(detailsStr) as Map<String, dynamic>;
                } catch (_) {}

                final timestamp = a['timestamp'] ?? a['createdAt'] ?? a['created_at'];
                final dateStr = timestamp != null ? formatDateTime(timestamp.toString()) : '-';
                
                String title = action.replaceAll('_', ' ');
                String subtitle = dateStr;
                IconData icon = Icons.info_outline_rounded;
                Color color = AppColors.accent;

                // Action-specific logic
                if (action == 'SESSION_CREATED') {
                  title = 'New Session Booked';
                  icon = Icons.event_available_rounded;
                  color = const Color(0xFF60A5FA);
                  final trainer = det['trainer'] ?? 'Trainer';
                  final member = det['member'] ?? 'Member';
                  subtitle = 'Trainer: $trainer with $member\n$dateStr';
                } else if (action == 'SESSION_DELETED') {
                  title = 'Session Deleted';
                  icon = Icons.delete_forever_rounded;
                  color = const Color(0xFFF87171);
                  final trainer = det['trainer'] ?? 'Trainer';
                  final member = det['member'] ?? 'Member';
                  subtitle = 'Deleted: $trainer with $member\n$dateStr';
                } else if (action == 'MEMBER_ADDED') {
                  title = 'Member Added';
                  icon = Icons.person_add_rounded;
                  color = const Color(0xFF4ADE80);
                  subtitle = 'Name: ${det['name'] ?? 'New Member'}\n$dateStr';
                } else if (action == 'MEMBER_CHECK_IN') {
                  title = 'Member Check-in';
                  icon = Icons.login_rounded;
                  color = AppColors.accent;
                  subtitle = 'Member: ${det['name'] ?? 'Member'}\n$dateStr';
                }

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: color.withAlpha(30),
                        child: Icon(icon, color: color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4)),
                          ],
                        ),
                      ),
                      if (a['adminName'] != null)
                        Text(a['adminName'].toString(), style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
