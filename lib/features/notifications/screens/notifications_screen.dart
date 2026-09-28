import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../shared/widgets/drawer_menu_button.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _filter = 'all'; // 'all' | 'unread'

  void _handleNotificationTap(InAppNotification notif) {
    if (!notif.isRead) {
      ref.read(notificationsProvider.notifier).markAsRead(notif.id);
    }

    final link = notif.link;
    if (link == null || link.isEmpty) return;

    try {
      if (link.contains('/members')) {
        context.push(AppRoutes.members);
      } else if (link.contains('/checkin') || link.contains('/check-in')) {
        context.push(AppRoutes.checkin);
      } else if (link.contains('/transactions') || link.contains('/invoices') || link.contains('/payments')) {
        context.push(AppRoutes.transactions);
      } else if (link.contains('/sessions')) {
        context.push(AppRoutes.sessions);
      } else if (link.contains('/classes')) {
        context.push(AppRoutes.classes);
      } else if (link.contains('/dashboard')) {
        context.push(AppRoutes.dashboard);
      }
    } catch (e) {
      debugPrint('[NotificationsScreen] Navigation error: $e');
    }
  }

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return 'Baru saja';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m yang lalu';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}j yang lalu';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}h yang lalu';
    } else {
      return DateFormat('d MMM yyyy').format(dt);
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type?.toUpperCase()) {
      case 'NEW_MEMBER':
        return Icons.person_add_alt_1_rounded;
      case 'INVOICE':
      case 'PAYMENT':
        return Icons.receipt_long_rounded;
      case 'CHECK_IN':
      case 'ATTENDANCE':
        return Icons.qr_code_scanner_rounded;
      case 'SESSION':
        return Icons.fitness_center_rounded;
      case 'REMINDER':
        return Icons.alarm_rounded;
      case 'ANNOUNCEMENT':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type?.toUpperCase()) {
      case 'NEW_MEMBER':
        return const Color(0xFF10B981); // Emerald green
      case 'INVOICE':
      case 'PAYMENT':
        return const Color(0xFFF59E0B); // Amber / gold
      case 'CHECK_IN':
      case 'ATTENDANCE':
        return const Color(0xFF3B82F6); // Blue
      case 'SESSION':
        return const Color(0xFF8B5CF6); // Purple
      case 'REMINDER':
        return const Color(0xFFEC4899); // Pink
      default:
        return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                onPressed: () => context.pop(),
              )
            : const DrawerMenuButton(),
        title: const Text(
          'Notifikasi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: () {
                ref.read(notificationsProvider.notifier).markAllAsRead();
              },
              icon: const Icon(Icons.done_all_rounded, size: 16, color: AppColors.accent),
              label: const Text(
                'Tandai Dibaca',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.surface,
            child: Row(
              children: [
                _buildFilterChip('all', 'Semua'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'unread',
                  unreadCount > 0 ? 'Belum Dibaca ($unreadCount)' : 'Belum Dibaca',
                ),
              ],
            ),
          ),

          // Notification List
          Expanded(
            child: notificationsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        'Gagal memuat notifikasi: $err',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.read(notificationsProvider.notifier).refresh(),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.surface),
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (list) {
                final filtered = _filter == 'unread'
                    ? list.where((n) => !n.isRead).toList()
                    : list;

                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    color: AppColors.accent,
                    backgroundColor: AppColors.card,
                    onRefresh: () async {
                      await ref.read(notificationsProvider.notifier).refresh();
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Icon(
                                  Icons.notifications_none_rounded,
                                  size: 36,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _filter == 'unread'
                                    ? 'Tidak ada notifikasi belum dibaca'
                                    : 'Belum ada notifikasi',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 40),
                                child: Text(
                                  'Aktivitas member, check-in, dan transaksi gym akan muncul di sini.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.accent,
                  backgroundColor: AppColors.card,
                  onRefresh: () async {
                    await ref.read(notificationsProvider.notifier).refresh();
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final notif = filtered[i];
                      final icon = _getNotificationIcon(notif.type);
                      final color = _getNotificationColor(notif.type);
                      final timeStr = _formatTimestamp(notif.createdAt);

                      return InkWell(
                        onTap: () => _handleNotificationTap(notif),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: notif.isRead
                                ? AppColors.card
                                : AppColors.card.withAlpha(240),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: notif.isRead
                                  ? AppColors.border
                                  : AppColors.accent.withAlpha(70),
                              width: notif.isRead ? 1 : 1.5,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Type icon
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color.withAlpha(30),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(icon, color: color, size: 20),
                              ),
                              const SizedBox(width: 12),

                              // Text content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            notif.title,
                                            style: TextStyle(
                                              color: notif.isRead
                                                  ? AppColors.textSecondary
                                                  : AppColors.textPrimary,
                                              fontSize: 14,
                                              fontWeight: notif.isRead
                                                  ? FontWeight.w500
                                                  : FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (timeStr.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            timeStr,
                                            style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      notif.message,
                                      style: TextStyle(
                                        color: notif.isRead
                                            ? AppColors.textMuted
                                            : AppColors.textSecondary,
                                        fontSize: 12.5,
                                        height: 1.35,
                                      ),
                                    ),
                                    if (notif.link != null && notif.link!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      const Row(
                                        children: [
                                          Text(
                                            'Ketuk untuk lihat detail',
                                            style: TextStyle(
                                              color: AppColors.accent,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 11,
                                            color: AppColors.accent,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Unread indicator dot
                              if (!notif.isRead) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.accent : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : AppColors.textMuted,
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
