import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';

final staffListProvider = FutureProvider.autoDispose<List<StaffInfo>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return [];
  return ref.read(apiRepositoryProvider).getStaffMembers(gymId);
});

final staffSchedulesProvider = FutureProvider.autoDispose<List<StaffSchedule>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return [];
  return ref.read(apiRepositoryProvider).getStaffAttendanceSchedules(gymId);
});

final attendanceStatsFilterProvider = StateProvider.autoDispose<Map<String, dynamic>>((ref) => {});

final attendanceStatsProvider = FutureProvider.autoDispose<AttendanceStats?>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return null;
  final filters = ref.watch(attendanceStatsFilterProvider);
  return ref.read(apiRepositoryProvider).getAttendanceStatistics(
    gymId,
    startDate: filters['startDate'] as String?,
    endDate: filters['endDate'] as String?,
    staffId: filters['staffId'] as String?,
  );
});
