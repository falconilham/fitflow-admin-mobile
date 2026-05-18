import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/utils/error_handler.dart';

final classRosterProvider = FutureProvider.family.autoDispose<Map<String, dynamic>, int>((ref, classId) async {
  return ref.read(apiRepositoryProvider).getClassBookings(classId);
});

class ClassRosterScreen extends ConsumerStatefulWidget {
  final int classId;
  const ClassRosterScreen({super.key, required this.classId});

  @override
  ConsumerState<ClassRosterScreen> createState() => _ClassRosterScreenState();
}

final memberSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final activeMembersListProvider = FutureProvider.family.autoDispose<List<Member>, String>((ref, search) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return [];
  return ref.read(apiRepositoryProvider).getMembers(gymId, search: search, limit: 15);
});

class _ClassRosterScreenState extends ConsumerState<ClassRosterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _mutating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _markAttendance(int bookingId, String status) async {
    setState(() => _mutating = true);
    try {
      await ref.read(apiRepositoryProvider).markClassAttendance(widget.classId, bookingId, status);
      ref.invalidate(classRosterProvider(widget.classId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'attended' ? 'Attendance marked: Attended!' : 'Attendance marked: No Show!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.parse(e)), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _cancelBooking(int bookingId, {bool isWaitlist = false}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(isWaitlist ? 'Remove from Waitlist?' : 'Cancel Booking?', style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(
          isWaitlist
              ? 'Are you sure you want to remove this member from the class waitlist?'
              : 'Cancelling will instantly promote the first member on the waitlist (if any) to active.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _mutating = true);
    try {
      await ref.read(apiRepositoryProvider).cancelClassBooking(widget.classId, bookingId);
      ref.invalidate(classRosterProvider(widget.classId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking removed successfully!'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.parse(e)), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  void _showAddMemberPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return const AddMemberRosterPickerSheet();
      },
    ).then((selectedMemberId) async {
      if (selectedMemberId is int) {
        setState(() => _mutating = true);
        try {
          await ref.read(apiRepositoryProvider).addClassMember(widget.classId, selectedMemberId);
          ref.invalidate(classRosterProvider(widget.classId));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Member successfully registered/added to queue!'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(ErrorHandler.parse(e)), behavior: SnackBarBehavior.floating),
            );
          }
        } finally {
          if (mounted) setState(() => _mutating = false);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rosterAsync = ref.watch(classRosterProvider(widget.classId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('CLASS ROSTER'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            onPressed: () => ref.invalidate(classRosterProvider(widget.classId)),
          ),
        ],
      ),
      body: rosterAsync.when(
        data: (data) {
          final GymClass gymClass = data['class'] as GymClass;
          final Map<String, List<ClassBooking>> grouped = data['grouped'] as Map<String, List<ClassBooking>>;
          
          final List<ClassBooking> confirmed = grouped['booked'] ?? [];
          final List<ClassBooking> waitlist = grouped['waitlist'] ?? [];
          
          // Combine attended, no_show, and cancelled for history
          final List<ClassBooking> history = [
            ...(grouped['attended'] ?? []),
            ...(grouped['no_show'] ?? []),
            ...(grouped['cancelled'] ?? []),
          ]..sort((a, b) => b.bookedAt.compareTo(a.bookedAt)); // sort newest first

          return Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Class info header
                  _buildHeader(gymClass),

                  // Tabs
                  Container(
                    color: AppColors.card,
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.accent,
                      labelColor: AppColors.accent,
                      unselectedLabelColor: AppColors.textMuted,
                      dividerColor: AppColors.border,
                      tabs: [
                        Tab(text: 'Active (${confirmed.length})'),
                        Tab(text: 'Waitlist (${waitlist.length})'),
                        Tab(text: 'History (${history.length})'),
                      ],
                    ),
                  ),

                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildConfirmedList(confirmed),
                        _buildWaitlistList(waitlist),
                        _buildHistoryList(history),
                      ],
                    ),
                  ),
                ],
              ),
              if (_mutating)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(ErrorHandler.parse(err), style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMemberPicker,
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.black),
      ),
    );
  }

  Widget _buildHeader(GymClass gymClass) {
    Color accentColor = AppColors.accent;
    if (gymClass.color != null && gymClass.color!.startsWith('#')) {
      try {
        accentColor = Color(int.parse('FF${gymClass.color!.replaceAll('#', '')}', radix: 16));
      } catch (_) {}
    }

    return Container(
      width: double.infinity,
      color: AppColors.card,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Category tag
              if (gymClass.categoryName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    gymClass.categoryName!.toUpperCase(),
                    style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                ),
              // Day of the week
              Text(
                '${gymClass.day}, ${gymClass.time}',
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            gymClass.title,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.person_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(gymClass.trainer, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Booked: ${gymClass.booked} / ${gymClass.capacity}',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmedList(List<ClassBooking> confirmed) {
    if (confirmed.isEmpty) {
      return _buildRosterEmptyState('No Active Bookings', 'Tap the + button to manually register a member.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: confirmed.length,
      itemBuilder: (ctx, index) {
        final b = confirmed[index];
        return Card(
          color: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.border)),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildAvatar(b.memberName, b.memberPhoto),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.memberName ?? 'Unknown Member', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                      if (b.memberIdString != null)
                        Text(b.memberIdString!, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                // Attendance Action Triggers
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline_rounded, color: AppColors.success),
                      tooltip: 'Mark Attended',
                      onPressed: () => _markAttendance(b.id, 'attended'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                      tooltip: 'Mark No Show',
                      onPressed: () => _markAttendance(b.id, 'no_show'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textMuted),
                      tooltip: 'Remove Booking',
                      onPressed: () => _cancelBooking(b.id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWaitlistList(List<ClassBooking> waitlist) {
    if (waitlist.isEmpty) {
      return _buildRosterEmptyState('No Waitlist Queue', 'If the class capacity overflows, members will appear here in chronological order.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: waitlist.length,
      itemBuilder: (ctx, index) {
        final b = waitlist[index];
        return Card(
          color: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.border)),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Queue Position Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.warning.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    '#${b.waitlistPosition ?? (index + 1)}',
                    style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.memberName ?? 'Unknown Member', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                      if (b.memberIdString != null)
                        Text(b.memberIdString!, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textMuted),
                  tooltip: 'Remove from Waitlist',
                  onPressed: () => _cancelBooking(b.id, isWaitlist: true),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryList(List<ClassBooking> history) {
    if (history.isEmpty) {
      return _buildRosterEmptyState('No History Records', 'Completed sessions, no-shows, and cancellations will be archived here.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (ctx, index) {
        final b = history[index];
        
        // Setup tag visual based on status
        Color statusColor = AppColors.textMuted;
        String statusText = b.status.toUpperCase();
        if (b.status == 'attended') {
          statusColor = AppColors.success;
          statusText = 'ATTENDED';
        } else if (b.status == 'no_show') {
          statusColor = AppColors.error;
          statusText = 'NO SHOW';
        } else if (b.status == 'cancelled') {
          statusColor = AppColors.textMuted;
          statusText = 'CANCELLED';
        }

        return Card(
          color: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: AppColors.border.withAlpha(120))),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildAvatar(b.memberName, b.memberPhoto, opacity: 0.6),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.memberName ?? 'Unknown Member',
                        style: TextStyle(
                          color: AppColors.textPrimary.withAlpha(180),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (b.memberIdString != null)
                        Text(b.memberIdString!, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withAlpha(60), width: 0.5),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(String? name, String? photo, {double opacity = 1.0}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Opacity(
          opacity: opacity,
          child: Text(
            name != null && name.isNotEmpty ? name[0].toUpperCase() : 'M',
            style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildRosterEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline_rounded, size: 36, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AddMemberRosterPickerSheet — Bottom Sheet containing search and add member
// ---------------------------------------------------------------------------
class AddMemberRosterPickerSheet extends ConsumerStatefulWidget {
  const AddMemberRosterPickerSheet({super.key});

  @override
  ConsumerState<AddMemberRosterPickerSheet> createState() => _AddMemberRosterPickerSheetState();
}

class _AddMemberRosterPickerSheetState extends ConsumerState<AddMemberRosterPickerSheet> {
  final _searchCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(memberSearchQueryProvider);
    final membersAsync = ref.watch(activeMembersListProvider(query));

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header indicator
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Add Member to Class', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              
              // Search Input
              TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search members by name or ID...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchCtrl.clear();
                            ref.read(memberSearchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                  isDense: true,
                ),
                onChanged: (val) {
                  ref.read(memberSearchQueryProvider.notifier).state = val.trim();
                },
              ),
              const SizedBox(height: 16),

              // Members List
              Expanded(
                child: membersAsync.when(
                  data: (members) {
                    if (members.isEmpty) {
                      return const Center(
                        child: Text('No active members found.', style: TextStyle(color: AppColors.textMuted)),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: members.length,
                      itemBuilder: (ctx, idx) {
                        final m = members[idx];
                        
                        // Setup status tag colors
                        Color statusColor = AppColors.success;
                        if (m.status == 'expired') statusColor = AppColors.error;
                        if (m.status == 'suspended') statusColor = AppColors.warning;

                        return Card(
                          color: AppColors.surface,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)),
                          child: ListTile(
                            onTap: () {
                              Navigator.pop(context, m.id);
                            },
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(6)),
                              child: Center(
                                child: Text(m.name[0].toUpperCase(), style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900)),
                              ),
                            ),
                            title: Text(m.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(m.memberId ?? 'No ID', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: statusColor.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                              child: Text(
                                m.status.toUpperCase(),
                                style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  error: (err, _) => Center(child: Text(ErrorHandler.parse(err), style: const TextStyle(color: AppColors.error))),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
