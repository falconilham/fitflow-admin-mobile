import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/drawer_menu_button.dart';
import '../../../shared/utils/error_handler.dart';

// ── Providers ──────────────────────────────────────────────────────────────
final _sessionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return [];
  try {
    return await ref.read(apiRepositoryProvider).getSessions(gymId);
  } on DioException catch (e) {
    if (e.response?.statusCode == 403 || e.response?.statusCode == 404) {
      return [];
    }
    rethrow;
  }
});

final _sessionMembersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return [];
  final raw =
      await ref.read(apiRepositoryProvider).getMembersRaw(gymId, limit: 1000);
  final list = raw['data'] ?? raw['members'] ?? [];
  if (list is List) return list.cast<Map<String, dynamic>>();
  return [];
});

final _sessionTrainersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return [];
  try {
    return await ref.read(apiRepositoryProvider).getTrainers(gymId);
  } on DioException catch (e) {
    if (e.response?.statusCode == 403 || e.response?.statusCode == 404) {
      return [];
    }
    rethrow;
  }
});

// ── Helpers ────────────────────────────────────────────────────────────────
const _statusOptions = <_StatusOpt>[
  _StatusOpt('scheduled', 'Scheduled', Color(0xFF60A5FA)),
  _StatusOpt('completed', 'Completed', Color(0xFF4ADE80)),
  _StatusOpt('cancelled', 'Cancelled', AppColors.error),
  _StatusOpt('no show', 'No Show', Color(0xFFFBBF24)),
  _StatusOpt('rescheduled', 'Rescheduled', Color(0xFFA78BFA)),
  _StatusOpt('unscheduled', 'Unscheduled', AppColors.textMuted),
];

class _StatusOpt {
  final String key;
  final String label;
  final Color color;
  const _StatusOpt(this.key, this.label, this.color);
}

_StatusOpt _statusForKey(String key) {
  return _statusOptions.firstWhere(
    (s) => s.key.toLowerCase() == key.toLowerCase(),
    orElse: () => const _StatusOpt('scheduled', 'Scheduled', Color(0xFF60A5FA)),
  );
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString())?.toLocal();
}

bool _isLocked(DateTime? scheduledAt, String status) {
  if (scheduledAt == null) return false;
  if (status != 'scheduled') return false;
  return scheduledAt.difference(DateTime.now()).inMinutes < 60;
}

bool _isMemberActive(Map<String, dynamic> m) {
  final status = (m['status'] as String? ?? '').toLowerCase();
  if (status == 'expired' || status == 'deleted') return false;
  final endDate = m['endDate'] as String?;
  if (endDate != null && endDate.isNotEmpty) {
    try {
      final end = DateTime.parse(endDate);
      final today = DateTime.now();
      if (DateTime(end.year, end.month, end.day)
          .isBefore(DateTime(today.year, today.month, today.day))) {
        return false;
      }
    } catch (_) {}
  }
  return true;
}

// ── Main Screen ────────────────────────────────────────────────────────────
class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // Filters (shared across tabs)
  String _search = '';
  int? _trainerFilter;
  String _statusFilter = 'ALL'; // ALL or specific status
  DateTime? _startDate;
  DateTime? _endDate;

  Timer? _debounce;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _search = v.trim().toLowerCase());
    });
    setState(() {}); // clear button visibility
  }

  void _resetFilters() {
    setState(() {
      _search = '';
      _trainerFilter = null;
      _statusFilter = 'ALL';
      _startDate = null;
      _endDate = null;
      _searchCtrl.clear();
    });
  }

  bool _matchesFilters(Map<String, dynamic> s) {
    // Search by member name
    if (_search.isNotEmpty) {
      final memberName = (s['member']?['name'] ?? s['memberName'] ?? '')
          .toString()
          .toLowerCase();
      final trainerName = (s['trainer']?['name'] ?? s['trainerName'] ?? '')
          .toString()
          .toLowerCase();
      if (!memberName.contains(_search) && !trainerName.contains(_search)) {
        return false;
      }
    }
    if (_trainerFilter != null) {
      final tid = s['trainerId'] ?? s['trainer']?['id'];
      if (tid != _trainerFilter) return false;
    }
    if (_statusFilter != 'ALL') {
      final st = (s['status'] ?? '').toString().toLowerCase();
      if (st != _statusFilter) return false;
    }
    if (_startDate != null || _endDate != null) {
      final dt = _parseDate(s['scheduledAt']);
      if (dt == null) return false;
      if (_startDate != null && dt.isBefore(_startDate!)) return false;
      if (_endDate != null) {
        final endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day,
            23, 59, 59);
        if (dt.isAfter(endOfDay)) return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final sessAsync = ref.watch(_sessionsProvider);
    ref.watch(_sessionMembersProvider);
    ref.watch(_sessionTrainersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Sessions',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
            onPressed: () => ref.invalidate(_sessionsProvider),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.accent,
          indicatorWeight: 2.5,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'History'),
            Tab(text: 'Unscheduled'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openSessionForm(),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add_rounded, color: Colors.black),
      ),
      body: sessAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
        error: (e, _) => Center(
            child: Text(ErrorHandler.parse(e),
                style: const TextStyle(color: AppColors.error))),
        data: (list) {
          // Analytics
          final analytics = _computeAnalytics(list);

          // Bucket sessions
          final now = DateTime.now();
          final List<Map<String, dynamic>> upcoming = [];
          final List<Map<String, dynamic>> history = [];
          final List<Map<String, dynamic>> unscheduled = [];

          for (final s in list) {
            final status = (s['status'] ?? '').toString().toLowerCase();
            if (status == 'unscheduled') {
              unscheduled.add(s);
              continue;
            }
            final dt = _parseDate(s['scheduledAt']);
            if (dt == null) {
              unscheduled.add(s);
              continue;
            }
            if (status == 'scheduled' && dt.isAfter(now)) {
              upcoming.add(s);
            } else {
              history.add(s);
            }
          }
          upcoming.sort((a, b) =>
              (_parseDate(a['scheduledAt']) ?? now).compareTo(_parseDate(b['scheduledAt']) ?? now));
          history.sort((a, b) =>
              (_parseDate(b['scheduledAt']) ?? now).compareTo(_parseDate(a['scheduledAt']) ?? now));

          // Apply filters
          final upcomingF = upcoming.where(_matchesFilters).toList();
          final historyF = history.where(_matchesFilters).toList();
          final unschedF = unscheduled.where(_matchesFilters).toList();

          return Column(
            children: [
              _AnalyticsStrip(analytics: analytics),
              _FilterBar(
                searchCtrl: _searchCtrl,
                onSearch: _onSearchChanged,
                trainerFilter: _trainerFilter,
                statusFilter: _statusFilter,
                startDate: _startDate,
                endDate: _endDate,
                onTrainerChange: (v) => setState(() => _trainerFilter = v),
                onStatusChange: (v) => setState(() => _statusFilter = v),
                onStartDate: (d) => setState(() => _startDate = d),
                onEndDate: (d) => setState(() => _endDate = d),
                onReset: _resetFilters,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _SessionList(
                      sessions: upcomingF,
                      tab: _Tab.upcoming,
                      onEdit: _openSessionForm,
                      onQuickStatus: _confirmStatusChange,
                      onDelete: _delete,
                    ),
                    _SessionList(
                      sessions: historyF,
                      tab: _Tab.history,
                      onEdit: _openSessionForm,
                      onQuickStatus: _confirmStatusChange,
                      onDelete: _delete,
                    ),
                    _SessionList(
                      sessions: unschedF,
                      tab: _Tab.unscheduled,
                      onEdit: _openSessionForm,
                      onQuickStatus: _confirmStatusChange,
                      onDelete: _delete,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Analytics ────────────────────────────────────────────────────────
  _SessionsAnalytics _computeAnalytics(List<Map<String, dynamic>> list) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    int totalMTD = 0;
    double ptRevenueMTD = 0;
    int completed = 0;
    int noShow = 0;
    int upcoming7 = 0;
    final in7 = now.add(const Duration(days: 7));

    for (final s in list) {
      final status = (s['status'] ?? '').toString().toLowerCase();
      final dt = _parseDate(s['scheduledAt']);
      if (dt != null &&
          dt.isAfter(monthStart) &&
          dt.isBefore(now) &&
          status != 'unscheduled' &&
          status != 'cancelled') {
        totalMTD++;
      }
      if (status == 'completed') {
        completed++;
        if (dt != null && dt.isAfter(monthStart)) {
          ptRevenueMTD += ((s['price'] ?? 0) as num).toDouble();
        }
      }
      if (status == 'no show') noShow++;
      if (status == 'scheduled' &&
          dt != null &&
          dt.isAfter(now) &&
          dt.isBefore(in7)) {
        upcoming7++;
      }
    }

    final attendanceTotal = completed + noShow;
    final attendanceRate =
        attendanceTotal > 0 ? (completed / attendanceTotal) * 100 : 0.0;

    return _SessionsAnalytics(
      totalMTD: totalMTD,
      ptRevenueMTD: ptRevenueMTD,
      attendanceRate: attendanceRate,
      upcoming7Days: upcoming7,
    );
  }

  // ── Quick status change ───────────────────────────────────────────────
  Future<void> _confirmStatusChange(
      Map<String, dynamic> session, String newStatus) async {
    final id = (session['id'] as num).toInt();
    final currentStatus = (session['status'] ?? '').toString().toLowerCase();
    final memberName =
        (session['member']?['name'] ?? session['memberName'] ?? 'this member')
            .toString();
    final hasPackage = (session['trainerPackageId'] ?? 0) != 0;
    bool refundToPackage = newStatus == 'cancelled' && hasPackage;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text('Ubah Status?',
              style: TextStyle(color: _statusForKey(newStatus).color)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ubah status sesi $memberName dari "$currentStatus" ke "$newStatus"?',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
              if (newStatus == 'cancelled' && hasPackage) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: refundToPackage,
                        activeColor: AppColors.accent,
                        onChanged: (v) =>
                            setSt(() => refundToPackage = v ?? false),
                      ),
                      const Expanded(
                        child: Text(
                          'Refund 1 sesi ke paket member',
                          style: TextStyle(
                              color: AppColors.textPrimary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Konfirmasi')),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(apiRepositoryProvider).updateSession(id, {
        'status': newStatus,
        if (newStatus == 'cancelled' && refundToPackage)
          'refundToPackage': true,
      });
      ref.invalidate(_sessionsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ErrorHandler.parse(e)),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────
  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Hapus Session?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Aksi ini tidak bisa dibatalkan.',
            style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal',
                  style: TextStyle(color: AppColors.textMuted))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(apiRepositoryProvider).deleteSession(id);
      ref.invalidate(_sessionsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ErrorHandler.parse(e)),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ── Form ──────────────────────────────────────────────────────────────
  void _openSessionForm([Map<String, dynamic>? session]) {
    final members = ref.read(_sessionMembersProvider).valueOrNull ?? [];
    final trainers = ref.read(_sessionTrainersProvider).valueOrNull ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SessionFormSheet(
        existing: session,
        members: members,
        trainers: trainers,
        onSaved: () {
          ref.invalidate(_sessionsProvider);
        },
      ),
    );
  }
}

enum _Tab { upcoming, history, unscheduled }

class _SessionsAnalytics {
  final int totalMTD;
  final double ptRevenueMTD;
  final double attendanceRate;
  final int upcoming7Days;
  const _SessionsAnalytics({
    required this.totalMTD,
    required this.ptRevenueMTD,
    required this.attendanceRate,
    required this.upcoming7Days,
  });
}

// ── Analytics Strip ────────────────────────────────────────────────────────
class _AnalyticsStrip extends StatelessWidget {
  final _SessionsAnalytics analytics;
  const _AnalyticsStrip({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _AnalyticTile(
            icon: Icons.calendar_today_rounded,
            color: const Color(0xFF60A5FA),
            label: 'TOTAL MTD',
            value: analytics.totalMTD.toString(),
          ),
          const SizedBox(width: 8),
          _AnalyticTile(
            icon: Icons.attach_money_rounded,
            color: AppColors.accent,
            label: 'REVENUE MTD',
            value: formatCurrency(analytics.ptRevenueMTD),
          ),
          const SizedBox(width: 8),
          _AnalyticTile(
            icon: Icons.percent_rounded,
            color: AppColors.success,
            label: 'ATTENDANCE',
            value: '${analytics.attendanceRate.toStringAsFixed(0)}%',
          ),
          const SizedBox(width: 8),
          _AnalyticTile(
            icon: Icons.upcoming_rounded,
            color: AppColors.warning,
            label: '7-DAY UPCOMING',
            value: analytics.upcoming7Days.toString(),
          ),
        ],
      ),
    );
  }
}

class _AnalyticTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _AnalyticTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 1),
                Text(value,
                    style: TextStyle(
                        color: color, fontSize: 14, fontWeight: FontWeight.w800),
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

// ── Filter Bar ─────────────────────────────────────────────────────────────
class _FilterBar extends ConsumerWidget {
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final int? trainerFilter;
  final String statusFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<int?> onTrainerChange;
  final ValueChanged<String> onStatusChange;
  final ValueChanged<DateTime?> onStartDate;
  final ValueChanged<DateTime?> onEndDate;
  final VoidCallback onReset;

  const _FilterBar({
    required this.searchCtrl,
    required this.onSearch,
    required this.trainerFilter,
    required this.statusFilter,
    required this.startDate,
    required this.endDate,
    required this.onTrainerChange,
    required this.onStatusChange,
    required this.onStartDate,
    required this.onEndDate,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainers = ref.watch(_sessionTrainersProvider).valueOrNull ?? [];
    final df = DateFormat('d MMM', 'id_ID');

    final hasAnyFilter = searchCtrl.text.isNotEmpty ||
        trainerFilter != null ||
        statusFilter != 'ALL' ||
        startDate != null ||
        endDate != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Search
          TextField(
            controller: searchCtrl,
            onChanged: onSearch,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Cari member atau trainer...',
              hintStyle:
                  const TextStyle(color: AppColors.textMuted, fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textMuted, size: 18),
              suffixIcon: searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          color: AppColors.textMuted, size: 16),
                      onPressed: () {
                        searchCtrl.clear();
                        onSearch('');
                      },
                    ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Trainer
                _filterChip(
                  icon: Icons.person_rounded,
                  label: trainerFilter == null
                      ? 'Trainer'
                      : (trainers.firstWhere(
                                  (t) => (t['id'] as num).toInt() == trainerFilter,
                                  orElse: () => {'name': 'Trainer'})['name'] ??
                              'Trainer')
                          .toString(),
                  active: trainerFilter != null,
                  onTap: () async {
                    final picked = await _pickFromList<int>(
                      context: context,
                      title: 'Pilih Trainer',
                      options: [
                        const _OptionEntry<int>(value: -1, label: 'Semua Trainer'),
                        for (final t in trainers)
                          _OptionEntry<int>(
                            value: (t['id'] as num).toInt(),
                            label: (t['name'] ?? 'Trainer').toString(),
                          ),
                      ],
                      current: trainerFilter ?? -1,
                    );
                    if (picked != null) onTrainerChange(picked == -1 ? null : picked);
                  },
                ),
                const SizedBox(width: 8),
                _filterChip(
                  icon: Icons.flag_rounded,
                  label: statusFilter == 'ALL'
                      ? 'Status'
                      : _statusForKey(statusFilter).label,
                  active: statusFilter != 'ALL',
                  onTap: () async {
                    final picked = await _pickFromList<String>(
                      context: context,
                      title: 'Pilih Status',
                      options: [
                        const _OptionEntry<String>(value: 'ALL', label: 'Semua Status'),
                        for (final s in _statusOptions)
                          _OptionEntry<String>(value: s.key, label: s.label),
                      ],
                      current: statusFilter,
                    );
                    if (picked != null) onStatusChange(picked);
                  },
                ),
                const SizedBox(width: 8),
                _filterChip(
                  icon: Icons.event_rounded,
                  label: startDate != null && endDate != null
                      ? '${df.format(startDate!)} – ${df.format(endDate!)}'
                      : startDate != null
                          ? 'Mulai ${df.format(startDate!)}'
                          : endDate != null
                              ? 'S/d ${df.format(endDate!)}'
                              : 'Tanggal',
                  active: startDate != null || endDate != null,
                  onTap: () => _showDateSheet(context),
                ),
                if (hasAnyFilter) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onReset,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.error.withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.error.withAlpha(80)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh_rounded,
                              size: 14, color: AppColors.error),
                          SizedBox(width: 4),
                          Text('Reset',
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              )),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.accent.withAlpha(30) : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? AppColors.accent : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: active ? AppColors.accent : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  color: active ? AppColors.accent : AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded,
                size: 16,
                color: active ? AppColors.accent : AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _showDateSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Filter Tanggal',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mulai',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                subtitle: Text(
                  startDate != null
                      ? DateFormat('d MMM yyyy', 'id_ID').format(startDate!)
                      : 'Belum dipilih',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.calendar_today_rounded,
                    color: AppColors.accent, size: 18),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await _pickDate(context,
                      initial: startDate ?? DateTime.now());
                  if (picked != null) onStartDate(picked);
                },
              ),
              const Divider(color: AppColors.border, height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Akhir',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                subtitle: Text(
                  endDate != null
                      ? DateFormat('d MMM yyyy', 'id_ID').format(endDate!)
                      : 'Belum dipilih',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.calendar_today_rounded,
                    color: AppColors.accent, size: 18),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await _pickDate(context,
                      initial: endDate ?? startDate ?? DateTime.now());
                  if (picked != null) onEndDate(picked);
                },
              ),
              const SizedBox(height: 12),
              if (startDate != null || endDate != null)
                TextButton.icon(
                  icon: const Icon(Icons.clear_rounded,
                      color: AppColors.error, size: 18),
                  label: const Text('Reset Tanggal',
                      style: TextStyle(color: AppColors.error)),
                  onPressed: () {
                    Navigator.pop(context);
                    onStartDate(null);
                    onEndDate(null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionEntry<T> {
  final T value;
  final String label;
  const _OptionEntry({required this.value, required this.label});
}

Future<T?> _pickFromList<T>({
  required BuildContext context,
  required String title,
  required List<_OptionEntry<T>> options,
  required T current,
}) async {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                  IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: options.map((opt) {
                  final selected = opt.value == current;
                  return ListTile(
                    title: Text(opt.label,
                        style: TextStyle(
                          color: selected
                              ? AppColors.accent
                              : AppColors.textPrimary,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w500,
                        )),
                    trailing: selected
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.accent)
                        : null,
                    onTap: () => Navigator.pop<T>(ctx, opt.value),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<DateTime?> _pickDate(BuildContext context,
    {required DateTime initial}) async {
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime.now().add(const Duration(days: 365)),
    builder: (ctx, child) => Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          onPrimary: Colors.black,
          surface: AppColors.card,
          onSurface: AppColors.textPrimary,
        ),
        dialogTheme: const DialogThemeData(backgroundColor: AppColors.card),
      ),
      child: child!,
    ),
  );
}

// ── Session List ───────────────────────────────────────────────────────────
class _SessionList extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  final _Tab tab;
  final void Function(Map<String, dynamic>) onEdit;
  final Future<void> Function(Map<String, dynamic>, String) onQuickStatus;
  final Future<void> Function(int) onDelete;

  const _SessionList({
    required this.sessions,
    required this.tab,
    required this.onEdit,
    required this.onQuickStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                tab == _Tab.upcoming
                    ? Icons.event_available_rounded
                    : tab == _Tab.history
                        ? Icons.history_rounded
                        : Icons.event_busy_rounded,
                size: 48,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 12),
              Text(
                tab == _Tab.upcoming
                    ? 'Tidak ada session mendatang'
                    : tab == _Tab.history
                        ? 'Belum ada history'
                        : 'Tidak ada session unscheduled',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final s = sessions[i];
        return _SessionCard(
          session: s,
          tab: tab,
          onEdit: () => onEdit(s),
          onAttended: tab == _Tab.upcoming
              ? () => onQuickStatus(s, 'completed')
              : null,
          onNoShow:
              tab == _Tab.upcoming ? () => onQuickStatus(s, 'no show') : null,
          onSchedule: tab == _Tab.unscheduled ? () => onEdit(s) : null,
          onDelete: () => onDelete((s['id'] as num).toInt()),
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final _Tab tab;
  final VoidCallback onEdit;
  final VoidCallback? onAttended;
  final VoidCallback? onNoShow;
  final VoidCallback? onSchedule;
  final VoidCallback onDelete;

  const _SessionCard({
    required this.session,
    required this.tab,
    required this.onEdit,
    required this.onAttended,
    required this.onNoShow,
    required this.onSchedule,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final s = session;
    final memberName =
        (s['member']?['name'] ?? s['memberName'] ?? 'Unknown').toString();
    final additionalMembers = (s['additionalMembers'] as List?)
        ?.map((m) => (m['name'] ?? '').toString())
        .where((n) => n.isNotEmpty)
        .toList() ?? [];
    final trainerName =
        (s['trainer']?['name'] ?? s['trainerName'] ?? '').toString();
    final specialty = (s['trainer']?['specialty'] ?? '').toString();
    final dt = _parseDate(s['scheduledAt']);
    final duration = (s['duration'] ?? 0) as num;
    final price = ((s['price'] ?? 0) as num).toDouble();
    final paymentMethod = (s['paymentMethod'] ?? '').toString();
    final notes = (s['notes'] ?? '').toString();
    final rescheduleReason = (s['rescheduleReason'] ?? '').toString();
    final exerciseLogRaw = s['exerciseLog'];
    final status = (s['status'] ?? 'scheduled').toString().toLowerCase();
    final statusOpt = _statusForKey(status);
    final commission = (s['commissionRateSnapshot'] as num?)?.toInt() ??
        (s['trainer']?['commissionPercentage'] as num?)?.toInt();
    final trainerShare = (s['trainerShare'] as num?)?.toDouble();
    final gymShare = (s['gymShare'] as num?)?.toDouble();
    final isPackage = paymentMethod == 'Package' ||
        (s['trainerPackageId'] ?? 0) != 0;
    final locked = _isLocked(dt, status);

    Map<String, dynamic>? exerciseLog;
    if (exerciseLogRaw is String && exerciseLogRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(exerciseLogRaw);
        if (decoded is Map<String, dynamic>) exerciseLog = decoded;
      } catch (_) {}
    } else if (exerciseLogRaw is Map<String, dynamic>) {
      exerciseLog = exerciseLogRaw;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 38,
                      decoration: BoxDecoration(
                        color: statusOpt.color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(memberName,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          if (additionalMembers.isNotEmpty)
                            Text(
                              '+${additionalMembers.join(', ')}',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (trainerName.isNotEmpty)
                            Text(
                              'with $trainerName${specialty.isNotEmpty ? ' • $specialty' : ''}',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusOpt.color.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusOpt.label.toUpperCase(),
                        style: TextStyle(
                            color: statusOpt.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _MetaPill(
                      icon: Icons.access_time_rounded,
                      text: dt != null
                          ? formatDateTime(dt.toIso8601String())
                          : 'Unscheduled',
                    ),
                    _MetaPill(
                      icon: Icons.timer_rounded,
                      text: '$duration min',
                    ),
                    if (price > 0)
                      _MetaPill(
                        icon: Icons.attach_money_rounded,
                        text: formatCurrency(price),
                        color: AppColors.accent,
                      ),
                    if (paymentMethod.isNotEmpty)
                      _MetaPill(
                        icon: isPackage
                            ? Icons.card_membership_rounded
                            : Icons.payments_rounded,
                        text: paymentMethod,
                        color: isPackage
                            ? AppColors.accent
                            : AppColors.textSecondary,
                        bold: isPackage,
                      ),
                    if (commission != null && commission > 0)
                      _MetaPill(
                        icon: Icons.percent_rounded,
                        text: '$commission% komisi',
                        color: const Color(0xFFA78BFA),
                      ),
                    if (status == 'completed' && trainerShare != null)
                      _MetaPill(
                        icon: Icons.person_rounded,
                        text: formatCurrency(trainerShare),
                        color: const Color(0xFF4ADE80),
                      ),
                    if (status == 'completed' && gymShare != null)
                      _MetaPill(
                        icon: Icons.store_rounded,
                        text: formatCurrency(gymShare),
                        color: const Color(0xFF60A5FA),
                      ),
                    if (locked)
                      const _MetaPill(
                        icon: Icons.lock_rounded,
                        text: 'Locked',
                        color: AppColors.warning,
                        bold: true,
                      ),
                  ],
                ),
                if (rescheduleReason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA78BFA).withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.swap_horiz_rounded,
                            size: 14, color: Color(0xFFA78BFA)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Reschedule: $rescheduleReason',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('📝 $notes',
                      style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontStyle: FontStyle.italic)),
                ],
                if (exerciseLog != null && exerciseLog.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('EXERCISE LOG',
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        for (final entry in exerciseLog.entries)
                          if (entry.value != null &&
                              entry.value.toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12),
                                  children: [
                                    TextSpan(
                                      text: '${entry.key}: ',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                    TextSpan(text: entry.value.toString()),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Actions bar
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                if (tab == _Tab.upcoming && status == 'scheduled') ...[
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onAttended,
                      icon: const Icon(Icons.check_circle_rounded,
                          size: 16, color: AppColors.success),
                      label: const Text('Attended',
                          style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                  ),
                  Container(width: 1, height: 30, color: AppColors.border),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onNoShow,
                      icon: const Icon(Icons.cancel_rounded,
                          size: 16, color: AppColors.warning),
                      label: const Text('No Show',
                          style: TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                  ),
                  Container(width: 1, height: 30, color: AppColors.border),
                ],
                if (tab == _Tab.unscheduled) ...[
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onSchedule,
                      icon: const Icon(Icons.event_available_rounded,
                          size: 16, color: AppColors.accent),
                      label: const Text('Schedule',
                          style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                  ),
                  Container(width: 1, height: 30, color: AppColors.border),
                ],
                Expanded(
                  child: TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded,
                        size: 16, color: AppColors.textSecondary),
                    label: const Text('Edit',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                ),
                Container(width: 1, height: 30, color: AppColors.border),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 16, color: AppColors.error),
                    label: const Text('Delete',
                        style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool bold;
  const _MetaPill({
    required this.icon,
    required this.text,
    this.color = AppColors.textSecondary,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            )),
      ],
    );
  }
}

// ─── Form Sheet ────────────────────────────────────────────────────────────
class _SessionFormSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> trainers;
  final VoidCallback onSaved;

  const _SessionFormSheet({
    required this.existing,
    required this.members,
    required this.trainers,
    required this.onSaved,
  });

  @override
  ConsumerState<_SessionFormSheet> createState() => _SessionFormSheetState();
}

class _SessionFormSheetState extends ConsumerState<_SessionFormSheet> {
  bool _submitting = false;
  late final bool _isEdit;

  int? _memberId;
  List<int> _additionalMemberIds = [];
  int? _trainerId;
  String _status = 'scheduled';
  DateTime? _scheduledAt;
  int _duration = 60;
  double _price = 0;
  String _paymentMethod = 'Cash';
  String _bookingType = 'single';
  int? _existingPackageId;
  int _newPackageSessions = 3;
  int _newPackagePrice = 1000000;
  int? _customCommission;
  bool _refundToPackage = true;
  DateTime? _originalScheduledAt;
  String _originalStatus = 'scheduled';

  List<Map<String, dynamic>> _availablePackages = [];
  bool _loadingPackages = false;

  final _notesCtrl = TextEditingController();
  final _rescheduleCtrl = TextEditingController();
  final _warmupCtrl = TextEditingController();
  final _mainLiftCtrl = TextEditingController();
  final _accessoryCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _isEdit = e != null;

    if (e != null) {
      _memberId = (e['memberId'] ?? e['member']?['id']) as int?;
      final rawExtra = e['additionalMemberIds'];
      if (rawExtra is List) {
        _additionalMemberIds = rawExtra.map((v) => (v as num).toInt()).toList();
      }
      _trainerId = (e['trainerId'] ?? e['trainer']?['id']) as int?;
      _status = (e['status'] ?? 'scheduled').toString().toLowerCase();
      _originalStatus = _status;
      _scheduledAt = _parseDate(e['scheduledAt']);
      _originalScheduledAt = _scheduledAt;
      _duration = (e['duration'] as num?)?.toInt() ?? 60;
      _price = ((e['price'] ?? 0) as num).toDouble();
      _paymentMethod =
          (e['paymentMethod'] ?? 'Cash').toString();
      _notesCtrl.text = (e['notes'] ?? '').toString();
      _existingPackageId = (e['trainerPackageId'] as num?)?.toInt();
      _bookingType =
          (_existingPackageId != null || _paymentMethod == 'Package')
              ? 'package'
              : 'single';
      _customCommission =
          (e['commissionRateSnapshot'] as num?)?.toInt();

      // Parse exerciseLog
      final exerciseRaw = e['exerciseLog'];
      Map<String, dynamic>? exerciseLog;
      if (exerciseRaw is String && exerciseRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(exerciseRaw);
          if (decoded is Map<String, dynamic>) exerciseLog = decoded;
        } catch (_) {}
      } else if (exerciseRaw is Map<String, dynamic>) {
        exerciseLog = exerciseRaw;
      }
      if (exerciseLog != null) {
        _warmupCtrl.text = (exerciseLog['warmup'] ?? '').toString();
        _mainLiftCtrl.text = (exerciseLog['mainLift'] ?? '').toString();
        _accessoryCtrl.text = (exerciseLog['accessory'] ?? '').toString();
      }
    } else {
      _scheduledAt = DateTime.now().add(const Duration(hours: 1));
    }

    // Auto-load packages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_memberId != null && _trainerId != null) _loadPackages();
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _rescheduleCtrl.dispose();
    _warmupCtrl.dispose();
    _mainLiftCtrl.dispose();
    _accessoryCtrl.dispose();
    super.dispose();
  }

  bool get _locked => _isLocked(_originalScheduledAt, _originalStatus);

  Future<void> _loadPackages() async {
    if (_memberId == null || _trainerId == null) return;
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    setState(() => _loadingPackages = true);
    try {
      final pkgs = await ref.read(apiRepositoryProvider).getTrainerPackages(
            gymId,
            memberId: _memberId,
            trainerId: _trainerId,
            status: 'active',
          );
      setState(() => _availablePackages = pkgs);
    } catch (_) {
      setState(() => _availablePackages = []);
    } finally {
      if (mounted) setState(() => _loadingPackages = false);
    }
  }

  Future<void> _pickDateTime() async {
    final initialDate = _scheduledAt ?? DateTime.now().add(const Duration(hours: 1));
    final now = DateTime.now();
    final firstDate = initialDate.isBefore(now) ? initialDate : now;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            onPrimary: Colors.black,
            surface: AppColors.card,
            onSurface: AppColors.textPrimary,
          ),
          dialogTheme: const DialogThemeData(backgroundColor: AppColors.card),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _scheduledAt != null
          ? TimeOfDay.fromDateTime(_scheduledAt!)
          : TimeOfDay.now(),
    );
    if (time == null) return;
    setState(() => _scheduledAt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit() async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    if (_memberId == null) {
      _toast('Pilih member dulu');
      return;
    }
    if (_trainerId == null) {
      _toast('Pilih trainer dulu');
      return;
    }
    if (_scheduledAt == null && _status != 'unscheduled') {
      _toast('Pilih waktu sesi');
      return;
    }
    if (_status == 'scheduled' && _scheduledAt != null) {
      final nowLimit = DateTime.now().subtract(const Duration(minutes: 5));
      if (_scheduledAt!.isBefore(nowLimit)) {
        _toast('Waktu sesi harus di masa depan');
        return;
      }
    }

    // Reschedule reason check (only when editing scheduled session and time changed)
    final timeChanged = _isEdit &&
        _originalScheduledAt != null &&
        _scheduledAt != null &&
        _originalScheduledAt!.toIso8601String() !=
            _scheduledAt!.toIso8601String();
    if (_isEdit &&
        _originalStatus == 'scheduled' &&
        timeChanged &&
        _rescheduleCtrl.text.trim().length < 10) {
      _toast('Alasan reschedule wajib (minimal 10 karakter)');
      return;
    }

    // Build exerciseLog from text fields
    Map<String, String>? exerciseLog;
    if (_warmupCtrl.text.isNotEmpty ||
        _mainLiftCtrl.text.isNotEmpty ||
        _accessoryCtrl.text.isNotEmpty) {
      exerciseLog = {
        if (_warmupCtrl.text.isNotEmpty) 'warmup': _warmupCtrl.text.trim(),
        if (_mainLiftCtrl.text.isNotEmpty)
          'mainLift': _mainLiftCtrl.text.trim(),
        if (_accessoryCtrl.text.isNotEmpty)
          'accessory': _accessoryCtrl.text.trim(),
      };
    }

    setState(() => _submitting = true);
    try {
      final data = <String, dynamic>{
        'gymId': gymId,
        'memberId': _memberId,
        if (_additionalMemberIds.isNotEmpty)
          'additionalMemberIds': _additionalMemberIds,
        'trainerId': _trainerId,
        'scheduledAt': (_scheduledAt ?? DateTime.now()).toUtc().toIso8601String(),
        'duration': _duration,
        'price': _price.toInt(),
        'paymentMethod': _paymentMethod,
        'status': _status,
        'notes': _notesCtrl.text.trim(),
        if (_customCommission != null) 'customCommissionRate': _customCommission,
        if (exerciseLog != null) 'exerciseLog': exerciseLog,
        if (_bookingType == 'package') ...{
          'trainerPackageId':
              _existingPackageId?.toString() ?? 'new-pending',
          if (_existingPackageId == null) ...{
            'packageTotalSessions': _newPackageSessions,
            'price': _newPackagePrice,
          },
        },
        if (timeChanged && _rescheduleCtrl.text.isNotEmpty)
          'rescheduleReason': _rescheduleCtrl.text.trim(),
        if (_isEdit &&
            _status == 'cancelled' &&
            _originalStatus != 'cancelled' &&
            _existingPackageId != null &&
            _refundToPackage)
          'refundToPackage': true,
      };

      if (_isEdit) {
        await ref
            .read(apiRepositoryProvider)
            .updateSession((widget.existing!['id'] as num).toInt(), data);
      } else {
        await ref.read(apiRepositoryProvider).createSession(data);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _toast(ErrorHandler.parse(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeChanged = _isEdit &&
        _originalScheduledAt != null &&
        _scheduledAt != null &&
        _originalScheduledAt!.toIso8601String() !=
            _scheduledAt!.toIso8601String();
    final wasPackage = _existingPackageId != null;
    final canRefund =
        _isEdit && _status == 'cancelled' && _originalStatus != 'cancelled' && wasPackage;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Text(
                  _isEdit
                      ? _locked
                          ? 'Update Status (Locked)'
                          : 'Edit Session'
                      : 'Add Session',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18),
                ),
                if (_locked) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withAlpha(30),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('LOCKED',
                        style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 9,
                            fontWeight: FontWeight.w800)),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            if (_locked)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Session ini terkunci karena <60 menit dari mulai. Hanya status, notes, exercise log, dan custom commission yang bisa diubah.',
                  style: TextStyle(color: AppColors.warning, fontSize: 11),
                ),
              ),

            // Status (edit only)
            if (_isEdit) ...[
              _fieldLabel('Status'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _statusOptions
                    .where((s) => s.key != 'unscheduled' || _status == 'unscheduled')
                    .map((s) {
                  final selected = s.key == _status;
                  return ChoiceChip(
                    label: Text(s.label),
                    selected: selected,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      color: selected ? Colors.black : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                    backgroundColor: AppColors.surface,
                    selectedColor: s.color,
                    onSelected: (_) => setState(() => _status = s.key),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Member dropdown (active only — exclude Expired/Deleted)
            _fieldLabel('Member (Aktif)'),
            _Dropdown<int>(
              value: _memberId,
              disabled: _isEdit,
              hint: 'Pilih Member',
              items: [
                for (final m in widget.members)
                  if (_isMemberActive(m))
                    _DropdownItem(
                        value: (m['id'] as num).toInt(),
                        label: (m['name'] ?? 'Member').toString()),
              ],
              onChanged: (v) {
                setState(() => _memberId = v);
                _loadPackages();
              },
            ),
            const SizedBox(height: 12),

            // Additional Members (group session, max 3 extra = 4 total, create only)
            if (!_isEdit) ...[
              _fieldLabel(
                  'Anggota Tambahan (maks 3, total ${1 + _additionalMemberIds.length}/4)'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final id in _additionalMemberIds)
                    Builder(builder: (ctx) {
                      final m = widget.members.firstWhere(
                        (m) => (m['id'] as num).toInt() == id,
                        orElse: () => {'name': 'Member'},
                      );
                      return Chip(
                        label: Text((m['name'] ?? 'Member').toString(),
                            style: const TextStyle(fontSize: 12)),
                        backgroundColor: AppColors.accent.withAlpha(30),
                        labelStyle:
                            const TextStyle(color: AppColors.accent),
                        deleteIconColor: AppColors.textMuted,
                        onDeleted: () => setState(() =>
                            _additionalMemberIds.remove(id)),
                      );
                    }),
                  if (_additionalMemberIds.length < 3)
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16,
                          color: AppColors.textMuted),
                      label: const Text('Tambah',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                      backgroundColor: AppColors.surface,
                      side: const BorderSide(color: AppColors.border),
                      onPressed: () async {
                        final activeMembers = widget.members
                            .where((m) =>
                                _isMemberActive(m) &&
                                (m['id'] as num).toInt() != _memberId &&
                                !_additionalMemberIds
                                    .contains((m['id'] as num).toInt()))
                            .toList();
                        if (activeMembers.isEmpty) return;
                        final picked = await showModalBottomSheet<int>(
                          context: context,
                          backgroundColor: AppColors.card,
                          builder: (_) => ListView(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Text('Pilih Member Tambahan',
                                    style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                              ),
                              for (final m in activeMembers)
                                ListTile(
                                  title: Text(
                                      (m['name'] ?? 'Member').toString(),
                                      style: const TextStyle(
                                          color: AppColors.textPrimary)),
                                  subtitle: Text(
                                      (m['email'] ?? '').toString(),
                                      style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12)),
                                  onTap: () => Navigator.pop(
                                      context,
                                      (m['id'] as num).toInt()),
                                ),
                            ],
                          ),
                        );
                        if (picked != null) {
                          setState(() => _additionalMemberIds.add(picked));
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Trainer dropdown
            _fieldLabel('Trainer'),
            _Dropdown<int>(
              value: _trainerId,
              disabled: _locked,
              hint: 'Pilih Trainer',
              items: [
                for (final t in widget.trainers)
                  _DropdownItem(
                    value: (t['id'] as num).toInt(),
                    label:
                        '${t['name']}${t['specialty'] != null ? ' • ${t['specialty']}' : ''}',
                  ),
              ],
              onChanged: (v) {
                setState(() {
                  _trainerId = v;
                  // Update default price from trainer if available
                  final tr = widget.trainers.firstWhere(
                      (t) => (t['id'] as num).toInt() == v,
                      orElse: () => {});
                  double calculatedPrice = ((tr['singleSessionPrice'] ??
                          tr['single_session_price'] ??
                          0) as num)
                      .toDouble();
                  if (_bookingType == 'single') {
                    final tiersRaw = tr['singleSessionTiers'] ?? tr['single_session_tiers'];
                    if (tiersRaw is String && tiersRaw.isNotEmpty) {
                      try {
                        final parsed = jsonDecode(tiersRaw);
                        if (parsed is List && parsed.isNotEmpty) {
                          calculatedPrice = ((parsed[0]['price'] ?? 0) as num).toDouble();
                        }
                      } catch (_) {}
                    }
                  }
                  _price = calculatedPrice;
                });
                _loadPackages();
              },
            ),
            const SizedBox(height: 12),

            // Booking type
            _fieldLabel('Tipe Booking'),
            Row(
              children: [
                Expanded(
                    child: ChoiceChip(
                  label: const Text('Single Visit'),
                  selected: _bookingType == 'single',
                  showCheckmark: false,
                  onSelected: _locked
                      ? null
                      : (_) => setState(() {
                            _bookingType = 'single';
                            _paymentMethod = 'Cash';
                            _existingPackageId = null;
                            _status = 'scheduled';
                            final tr = widget.trainers.firstWhere(
                                (t) => (t['id'] as num).toInt() == _trainerId,
                                orElse: () => {});
                            double calculatedPrice = ((tr['singleSessionPrice'] ??
                                    tr['single_session_price'] ??
                                    0) as num)
                                .toDouble();
                            final tiersRaw = tr['singleSessionTiers'] ?? tr['single_session_tiers'];
                            if (tiersRaw is String && tiersRaw.isNotEmpty) {
                              try {
                                final parsed = jsonDecode(tiersRaw);
                                if (parsed is List && parsed.isNotEmpty) {
                                  calculatedPrice = ((parsed[0]['price'] ?? 0) as num).toDouble();
                                }
                              } catch (_) {}
                            }
                            _price = calculatedPrice;
                          }),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: ChoiceChip(
                  label: const Text('Use Package'),
                  selected: _bookingType == 'package',
                  showCheckmark: false,
                  onSelected: _locked || _isEdit
                      ? null
                      : (_) => setState(() {
                            _bookingType = 'package';
                            _paymentMethod = 'Package';
                            _price = 0;
                            _status = 'unscheduled';
                          }),
                )),
              ],
            ),
            const SizedBox(height: 12),

            if (_bookingType == 'package') ...[
              _fieldLabel(_loadingPackages
                  ? 'Memuat paket...'
                  : _availablePackages.isEmpty
                      ? 'Tidak ada paket aktif'
                      : 'Paket Aktif'),
              _Dropdown<int>(
                value: _existingPackageId,
                disabled: _availablePackages.isEmpty,
                hint: 'Pilih paket',
                items: [
                  for (final p in _availablePackages)
                    _DropdownItem(
                      value: (p['id'] as num).toInt(),
                      label:
                          '${p['packageName'] ?? 'Package'} (${((p['totalSessions'] ?? 0) as num) - ((p['usedSessions'] ?? 0) as num)} sisa)',
                    ),
                ],
                onChanged: (v) => setState(() {
                  _existingPackageId = v;
                  if (v != null) _price = 0;
                }),
              ),
              if (_existingPackageId == null && !_isEdit) ...[
                const SizedBox(height: 8),
                const Text('atau beli paket baru:',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    [3, 1000000],
                    [5, 1500000],
                    [10, 2500000],
                  ].map((tier) {
                    final sess = tier[0];
                    final price = tier[1];
                    final selected = _newPackageSessions == sess;
                    return ChoiceChip(
                      showCheckmark: false,
                      label: Text(
                        '$sess sess · ${formatCurrency(price.toDouble())}',
                        style: TextStyle(
                            fontSize: 11,
                            color: selected
                                ? Colors.black
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700),
                      ),
                      selected: selected,
                      selectedColor: AppColors.accent,
                      backgroundColor: AppColors.surface,
                      onSelected: (_) => setState(() {
                        _newPackageSessions = sess;
                        _newPackagePrice = price;
                        _price = price.toDouble();
                      }),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
            ],

            if (_isEdit || _bookingType == 'single') ...[
              // Date & Time
              _fieldLabel('Tanggal & Waktu'),
              OutlinedButton.icon(
                onPressed: _locked ? null : _pickDateTime,
                icon: const Icon(Icons.event_rounded,
                    color: AppColors.textMuted, size: 16),
                label: Text(
                  _scheduledAt != null
                      ? formatDateTime(_scheduledAt!.toIso8601String())
                      : 'Pilih tanggal & waktu',
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Reschedule reason (only when scheduledAt of existing scheduled session changed)
            if (_isEdit && _originalStatus == 'scheduled' && timeChanged) ...[
              _fieldLabel('Alasan Reschedule (wajib, min 10 karakter)'),
              TextField(
                controller: _rescheduleCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Member request perpanjang waktu...',
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Duration + Price
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('Durasi (menit)'),
                      _Dropdown<int>(
                        value: _duration,
                        disabled: _isEdit,
                        hint: 'Durasi',
                        items: const [
                          _DropdownItem(value: 5, label: '5'),
                          _DropdownItem(value: 10, label: '10'),
                          _DropdownItem(value: 15, label: '15'),
                          _DropdownItem(value: 30, label: '30'),
                          _DropdownItem(value: 60, label: '60'),
                          _DropdownItem(value: 90, label: '90'),
                        ],
                        onChanged: (v) =>
                            setState(() => _duration = v ?? 60),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('Harga (IDR)'),
                      TextField(
                        enabled: !_locked,
                        controller: TextEditingController(
                            text: _price.toStringAsFixed(0)),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
                        ),
                        onChanged: (v) =>
                            _price = double.tryParse(v) ?? 0,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Payment method
            _fieldLabel('Metode Pembayaran'),
            _Dropdown<String>(
              value: _paymentMethod,
              disabled: _locked || (_bookingType == 'package' && _existingPackageId != null),
              hint: 'Pilih metode',
              items: const [
                _DropdownItem(value: 'Cash', label: 'Cash'),
                _DropdownItem(value: 'Transfer', label: 'Transfer'),
                _DropdownItem(value: 'QR', label: 'QR'),
                _DropdownItem(value: 'Package', label: 'Package'),
              ],
              onChanged: (v) => setState(() => _paymentMethod = v ?? 'Cash'),
            ),
            const SizedBox(height: 12),

            // Custom commission
            _fieldLabel('Komisi Override % (opsional)'),
            TextField(
              controller: TextEditingController(
                  text: _customCommission?.toString() ?? ''),
              keyboardType: TextInputType.number,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Kosongkan untuk pakai default trainer',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              ),
              onChanged: (v) {
                _customCommission = int.tryParse(v.trim());
              },
            ),
            const SizedBox(height: 12),

            // Refund to package
            if (canRefund)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppColors.warning.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _refundToPackage,
                      activeColor: AppColors.accent,
                      onChanged: (v) =>
                          setState(() => _refundToPackage = v ?? false),
                    ),
                    const Expanded(
                      child: Text(
                        'Refund 1 sesi ke paket member',
                        style: TextStyle(
                            color: AppColors.textPrimary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Exercise log (edit only)
            if (_isEdit) ...[
              _fieldLabel('Exercise Log (opsional)'),
              TextField(
                controller: _warmupCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Warm-up',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _mainLiftCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Main Lift (set/rep)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _accessoryCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Accessory / Others',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // General notes
            _fieldLabel('Catatan Internal'),
            TextField(
              controller: _notesCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Catatan untuk session ini...',
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : Text(_isEdit ? 'Update Session' : 'Add Session',
                        style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label,
          style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3)),
    );
  }
}

class _DropdownItem<T> {
  final T value;
  final String label;
  const _DropdownItem({required this.value, required this.label});
}

class _Dropdown<T> extends StatelessWidget {
  final T? value;
  final List<_DropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String hint;
  final bool disabled;

  const _Dropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.hint,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    // Make sure value exists in items
    final hasValue = value != null && items.any((e) => e.value == value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: disabled
            ? AppColors.surface.withAlpha(150)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: hasValue ? value : null,
          hint: Text(hint,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 13)),
          isExpanded: true,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          icon: const Icon(Icons.arrow_drop_down_rounded,
              color: AppColors.textMuted),
          onChanged: disabled ? null : onChanged,
          items: items
              .map((it) => DropdownMenuItem<T>(
                  value: it.value,
                  child: Text(it.label, overflow: TextOverflow.ellipsis)))
              .toList(),
        ),
      ),
    );
  }
}
