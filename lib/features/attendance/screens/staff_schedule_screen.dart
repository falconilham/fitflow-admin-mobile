import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/error_handler.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/attendance_providers.dart';

class StaffSchedulesScreen extends ConsumerWidget {
  const StaffSchedulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(staffSchedulesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Schedules'),
        backgroundColor: AppColors.surface,
      ),
      body: schedulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (err, stack) => Center(child: Text(ErrorHandler.parse(err), style: const TextStyle(color: AppColors.error))),
        data: (schedules) {
          if (schedules.isEmpty) {
            return const Center(
              child: Text('No schedules found. Add one below!', style: TextStyle(color: AppColors.textMuted)),
            );
          }

          // Group by day of week
          final days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
          final grouped = <String, List<StaffSchedule>>{};
          for (final d in days) {
            grouped[d] = [];
          }
          for (final s in schedules) {
            if (grouped.containsKey(s.dayOfWeek)) {
              grouped[s.dayOfWeek]!.add(s);
            }
          }

          return RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.card,
            onRefresh: () async => ref.refresh(staffSchedulesProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                final daySchedules = grouped[day]!;
                if (daySchedules.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 16),
                      child: Text(day, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    ...daySchedules.map((s) => _ScheduleCard(schedule: s)),
                  ],
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        onPressed: () => _showAddScheduleSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddScheduleSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const _AddScheduleForm(),
      ),
    );
  }
}

class _ScheduleCard extends ConsumerWidget {
  final StaffSchedule schedule;
  const _ScheduleCard({required this.schedule});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(schedule.staffName, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${schedule.role.toUpperCase()} • ${schedule.startTime} - ${schedule.endTime}',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.surface,
                title: const Text('Delete Schedule?'),
                content: const Text('This action cannot be undone.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
                ],
              ),
            );
            if (confirm == true) {
              try {
                await ref.read(apiRepositoryProvider).deleteStaffSchedule(schedule.id);
                ref.invalidate(staffSchedulesProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.parse(e)), backgroundColor: AppColors.error));
                }
              }
            }
          },
        ),
      ),
    );
  }
}

class _AddScheduleForm extends ConsumerStatefulWidget {
  const _AddScheduleForm();
  @override
  ConsumerState<_AddScheduleForm> createState() => _AddScheduleFormState();
}

class _AddScheduleFormState extends ConsumerState<_AddScheduleForm> {
  String? selectedStaffId;
  String? selectedDay;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  bool loading = false;

  final days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

  Future<void> _submit() async {
    if (selectedStaffId == null || selectedDay == null || startTime == null || endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;

    final formatTime = (TimeOfDay t) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    };

    setState(() => loading = true);
    try {
      await ref.read(apiRepositoryProvider).createStaffSchedule(gymId, {
        'staffId': selectedStaffId,
        'dayOfWeek': selectedDay,
        'startTime': formatTime(startTime!),
        'endTime': formatTime(endTime!),
      });
      ref.invalidate(staffSchedulesProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.parse(e)), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffListProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Add Schedule', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          
          staffAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Failed to load staff: ${ErrorHandler.parse(e)}', style: const TextStyle(color: AppColors.error)),
            data: (staffList) {
              return DropdownButtonFormField<String>(
                value: selectedStaffId,
                dropdownColor: AppColors.card,
                items: staffList.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(color: AppColors.textPrimary)))).toList(),
                onChanged: (v) => setState(() => selectedStaffId = v),
                decoration: const InputDecoration(labelText: 'Staff Member'),
              );
            },
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: selectedDay,
            dropdownColor: AppColors.card,
            items: days.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(color: AppColors.textPrimary)))).toList(),
            onChanged: (v) => setState(() => selectedDay = v),
            decoration: const InputDecoration(labelText: 'Day of Week'),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
                    if (t != null) setState(() => startTime = t);
                  },
                  child: Text(startTime != null ? startTime!.format(context) : 'Start Time'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 17, minute: 0));
                    if (t != null) setState(() => endTime = t);
                  },
                  child: Text(endTime != null ? endTime!.format(context) : 'End Time'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: loading ? null : _submit,
            child: loading ? const CircularProgressIndicator(color: Colors.black) : const Text('Save Schedule'),
          )
        ],
      ),
    );
  }
}
