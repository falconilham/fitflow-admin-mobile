import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/drawer_menu_button.dart';

final _sessionsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return [];
  try {
    return await ref.read(apiRepositoryProvider).getSessions(gymId);
  } on DioException catch (e) {
    if (e.response?.statusCode == 403 || e.response?.statusCode == 404) return [];
    rethrow;
  }
});

final _sessionMembersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return [];
  final raw = await ref.read(apiRepositoryProvider).getMembersRaw(gymId, limit: 200);
  final list = raw['data'] ?? raw['members'] ?? [];
  if (list is List) return list.cast<Map<String, dynamic>>();
  return [];
});

final _sessionTrainersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return [];
  try {
    return await ref.read(apiRepositoryProvider).getTrainers(gymId);
  } on DioException catch (e) {
    if (e.response?.statusCode == 403 || e.response?.statusCode == 404) return [];
    rethrow;
  }
});

class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  bool _submitting = false;
  int? _editingId;

  // Form state
  int? _selectedMemberId;
  int? _selectedTrainerId;
  String _status = 'scheduled';
  DateTime? _scheduledAt;
  int _duration = 60;
  double _price = 0;
  String _paymentMethod = 'Cash';
  String _bookingType = 'single'; // 'single' or 'package'
  int? _selectedPackageId; // Existing package ID
  int _packageSessions = 3; // For new package
  List<Map<String, dynamic>> _availablePackages = [];
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _showForm([Map<String, dynamic>? session]) {
    if (session != null) {
      _editingId = session['id'] as int?;
      _selectedMemberId = (session['memberId'] ?? session['member']?['id']) as int?;
      _selectedTrainerId = (session['trainerId'] ?? session['trainer']?['id']) as int?;
      _status = (session['status'] ?? 'scheduled').toString();
      final sat = session['scheduledAt'] ?? session['scheduled_at'];
      _scheduledAt = sat != null ? DateTime.tryParse(sat.toString()) : null;
      _duration = (session['duration'] ?? 60) as int;
      _price = ((session['price'] ?? 0) as num).toDouble();
      _paymentMethod = (session['paymentMethod'] ?? session['payment_method'] ?? 'Cash').toString();
      _notesCtrl.text = (session['notes'] ?? '').toString();
      _selectedPackageId = (session['trainerPackageId'] ?? session['trainer_package_id']) as int?;
      _bookingType = (_selectedPackageId != null || _paymentMethod == 'Package') ? 'package' : 'single';
    } else {
      _editingId = null;
      _selectedMemberId = null;
      _selectedTrainerId = null;
      _status = 'scheduled';
      _scheduledAt = null;
      _duration = 60;
      _price = 0;
      _paymentMethod = 'Cash';
      _bookingType = 'single';
      _selectedPackageId = null;
      _availablePackages = [];
      _notesCtrl.clear();
    }

    final members = ref.read(_sessionMembersProvider).valueOrNull ?? [];
    final trainers = ref.read(_sessionTrainersProvider).valueOrNull ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_editingId != null ? 'Edit Session' : 'Add Session',
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 16),

            if (_editingId != null) ...[
              _DropdownField<String>(
                label: 'Status',
                value: _status,
                items: const {'scheduled': 'Scheduled', 'completed': 'Completed', 'cancelled': 'Cancelled'},
                onChanged: (v) => setMState(() => _status = v!),
              ),
              const SizedBox(height: 10),
            ],

            // Member dropdown
            _DropdownField<int?>(
              label: 'Member',
              value: _selectedMemberId,
              items: {for (var m in members) (m['id'] as num).toInt(): (m['name'] ?? 'Member').toString()},
              onChanged: (v) async {
                setMState(() {
                  _selectedMemberId = v;
                });
                if (v != null && _selectedTrainerId != null) {
                  final pkgs = await ref.read(apiRepositoryProvider).getTrainerPackages(ref.read(authProvider).valueOrNull?.activeGymId ?? 0, memberId: v, trainerId: _selectedTrainerId, status: 'active');
                  setMState(() => _availablePackages = pkgs);
                }
              },
            ),
            const SizedBox(height: 10),

            // Trainer dropdown
            _DropdownField<int?>(
              label: 'Trainer',
              value: _selectedTrainerId,
              items: {for (var t in trainers) (t['id'] as num).toInt(): '${t['name'] ?? 'Trainer'} - ${t['specialty'] ?? ''}'},
              onChanged: (v) async {
                setMState(() {
                  _selectedTrainerId = v;
                  final tr = trainers.firstWhere((t) => (t['id'] as num).toInt() == v, orElse: () => {});
                  _price = ((tr['singleSessionPrice'] ?? tr['single_session_price'] ?? 0) as num).toDouble();
                });
                if (_selectedMemberId != null && v != null) {
                  final pkgs = await ref.read(apiRepositoryProvider).getTrainerPackages(gymId, memberId: _selectedMemberId, trainerId: v, status: 'active');
                  setMState(() => _availablePackages = pkgs);
                }
              },
            ),
            const SizedBox(height: 10),

            // Booking Type Toggle
            Row(children: [
              Expanded(child: ChoiceChip(
                label: const Text('Single Visit'),
                selected: _bookingType == 'single',
                onSelected: (s) => setMState(() {
                  _bookingType = 'single';
                  _paymentMethod = 'Cash';
                  final tr = trainers.firstWhere((t) => (t['id'] as num).toInt() == _selectedTrainerId, orElse: () => {});
                  _price = ((tr['singleSessionPrice'] ?? tr['single_session_price'] ?? 0) as num).toDouble();
                }),
              )),
              const SizedBox(width: 10),
              Expanded(child: ChoiceChip(
                label: const Text('Package'),
                selected: _bookingType == 'package',
                onSelected: (s) => setMState(() {
                  _bookingType = 'package';
                  _paymentMethod = 'Package';
                  _price = 0; // Total price will be set by tier
                }),
              )),
            ]),
            const SizedBox(height: 10),

            if (_bookingType == 'package') ...[
              // Existing Package Dropdown
              _DropdownField<int?>(
                label: _availablePackages.isEmpty ? 'No active packages' : 'Select Active Package',
                value: _selectedPackageId,
                items: {for (var p in _availablePackages) (p['id'] as num).toInt(): '${p['packageName'] ?? 'Package'} (${(p['totalSessions'] ?? 0) - (p['usedSessions'] ?? 0)} left)'},
                onChanged: (v) => setMState(() {
                  _selectedPackageId = v;
                  _price = 0; // Existing package means already paid
                }),
              ),
              const SizedBox(height: 10),

              if (_selectedPackageId == null) ...[
                const Text('Buy New Package', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Wrap(spacing: 8, children: [3, 5, 10].map((s) {
                  final p = s == 3 ? 1000000 : (s == 5 ? 1500000 : 2500000);
                  return ChoiceChip(
                    label: Text('$s sess @ ${formatCurrency(p.toDouble())}'),
                    selected: _packageSessions == s,
                    onSelected: (sel) => setMState(() {
                      _packageSessions = s;
                      _price = p.toDouble();
                    }),
                  );
                }).toList()),
                const SizedBox(height: 10),
              ],
            ],

            // Date/time picker button
            OutlinedButton.icon(
              onPressed: () async {
                final date = await showDatePicker(context: context, initialDate: _scheduledAt ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (date == null || !mounted) return;
                if (!context.mounted) return;
                final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                if (time == null) return;
                setMState(() => _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
              },
              icon: const Icon(Icons.access_time_rounded, color: AppColors.textMuted, size: 16),
              label: Text(
                _scheduledAt != null ? formatDateTime(_scheduledAt!.toIso8601String()) : 'Select Date & Time',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                alignment: Alignment.centerLeft,
              ),
            ),
            const SizedBox(height: 10),

            Row(children: [
              Expanded(child: _NumField(label: 'Duration (min)', value: _duration.toDouble(),
                onChanged: (v) => setMState(() => _duration = v.toInt()))),
              const SizedBox(width: 10),
              Expanded(child: _NumField(label: 'Price (IDR)', value: _price,
                onChanged: (v) => setMState(() => _price = v))),
            ]),
            const SizedBox(height: 10),

            _DropdownField<String>(
              label: 'Payment Method',
              value: _paymentMethod,
              items: const {'Cash': 'Cash', 'Transfer': 'Transfer', 'Package': 'Package', 'Other': 'Other'},
              onChanged: (v) => setMState(() => _paymentMethod = v!),
            ),
            const SizedBox(height: 10),

            TextField(controller: _notesCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes (optional)', labelStyle: const TextStyle(color: AppColors.textMuted),
                filled: true, fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              )),
            const SizedBox(height: 16),

            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _submitting ? null : () => _submit(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _submitting
                ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.black)
                : Text(_editingId != null ? 'Update' : 'Add Session', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
            )),
          ])),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext ctx) async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    if (_selectedMemberId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a member'))); return; }
    if (_selectedTrainerId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a trainer'))); return; }

    setState(() => _submitting = true);
    try {
      final data = {
        'gymId': gymId,
        'memberId': _selectedMemberId,
        'trainerId': _selectedTrainerId,
        'scheduledAt': (_scheduledAt ?? DateTime.now()).toIso8601String(),
        'duration': _duration,
        'price': _price,
        'paymentMethod': _paymentMethod,
        'status': _status,
        'notes': _notesCtrl.text.trim(),
        if (_bookingType == 'package') ...{
           'trainerPackageId': _selectedPackageId?.toString() ?? 'new-pending',
           if (_selectedPackageId == null) 'packageTotalSessions': _packageSessions,
        }
      };
      if (_editingId != null) {
        await ref.read(apiRepositoryProvider).updateSession(_editingId!, data);
      } else {
        await ref.read(apiRepositoryProvider).createSession(data);
      }
      ref.invalidate(_sessionsProvider);
      if (ctx.mounted) Navigator.pop(ctx);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('Delete Session?', style: TextStyle(color: AppColors.textPrimary)),
      content: const Text('This action cannot be undone.', style: TextStyle(color: AppColors.textMuted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
      ],
    ));
    if (confirm != true) return;
    try {
      await ref.read(apiRepositoryProvider).deleteSession(id);
      ref.invalidate(_sessionsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'completed': return const Color(0xFF4ADE80);
      case 'cancelled': return const Color(0xFFF87171);
      default: return const Color(0xFF60A5FA);
    }
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
        title: const Text('Sessions', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [Tab(text: 'Upcoming'), Tab(text: 'History')],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add_rounded, color: Colors.black),
      ),
      body: sessAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
        error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.error))),
        data: (list) {
          final now = DateTime.now();
          final upcoming = list.where((s) {
            final sat = s['scheduledAt'] ?? s['scheduled_at'];
            final dt = sat != null ? DateTime.tryParse(sat.toString()) : null;
            return dt != null && dt.isAfter(now);
          }).toList()..sort((a, b) {
            final da = DateTime.tryParse((a['scheduledAt'] ?? a['scheduled_at'] ?? '').toString()) ?? now;
            final db = DateTime.tryParse((b['scheduledAt'] ?? b['scheduled_at'] ?? '').toString()) ?? now;
            return da.compareTo(db);
          });
          final history = list.where((s) {
            final sat = s['scheduledAt'] ?? s['scheduled_at'];
            final dt = sat != null ? DateTime.tryParse(sat.toString()) : null;
            return dt == null || dt.isBefore(now);
          }).toList()..sort((a, b) {
            final da = DateTime.tryParse((a['scheduledAt'] ?? a['scheduled_at'] ?? '').toString()) ?? now;
            final db = DateTime.tryParse((b['scheduledAt'] ?? b['scheduled_at'] ?? '').toString()) ?? now;
            return db.compareTo(da);
          });

          return TabBarView(
            controller: _tabCtrl,
            children: [
              _SessionList(sessions: upcoming, upcoming: true, onEdit: _showForm, onDelete: _delete, statusColor: _statusColor),
              _SessionList(sessions: history, upcoming: false, onEdit: _showForm, onDelete: _delete, statusColor: _statusColor),
            ],
          );
        },
      ),
    );
  }
}

class _SessionList extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  final bool upcoming;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(int) onDelete;
  final Color Function(String) statusColor;

  const _SessionList({required this.sessions, required this.upcoming, required this.onEdit, required this.onDelete, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(child: Text(upcoming ? 'No upcoming sessions.' : 'No session history.', style: const TextStyle(color: AppColors.textMuted)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final s = sessions[i];
        final memberName = s['member']?['name'] ?? s['memberName'] ?? s['member_name'] ?? 'Unknown';
        final trainerName = s['trainer']?['name'] ?? s['trainerName'] ?? s['trainer_name'] ?? '';
        final specialty = s['trainer']?['specialty'] ?? '';
        final sat = s['scheduledAt'] ?? s['scheduled_at'];
        final dateStr = sat != null ? formatDateTime(sat.toString()) : '-';
        final duration = s['duration'] ?? 0;
        final price = (s['price'] ?? 0) as num;
        final status = (s['status'] ?? 'scheduled').toString();
        final method = s['paymentMethod'] ?? s['payment_method'] ?? '';
        final notes = s['notes'] ?? '';
        final sColor = statusColor(status);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 4, height: 40, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(memberName.toString(), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('with $trainerName${specialty.isNotEmpty ? ' • $specialty' : ''}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: sColor.withAlpha(30), borderRadius: BorderRadius.circular(20)),
                child: Text(status, style: TextStyle(color: sColor, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.access_time_rounded, color: AppColors.textMuted, size: 14),
              const SizedBox(width: 4),
              Text(dateStr, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(width: 16),
              const Icon(Icons.timer_rounded, color: AppColors.textMuted, size: 14),
              const SizedBox(width: 4),
              Text('$duration min', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              if (price > 0) ...[
                const SizedBox(width: 16),
                Text(formatCurrency(price.toDouble()), style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 12)),
                if (method.isNotEmpty) Text(' ($method)', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ]),
            if (notes.toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Note: $notes', style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontStyle: FontStyle.italic)),
            ],
            if (upcoming) ...[
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton.icon(
                  onPressed: () => onEdit(s),
                  icon: const Icon(Icons.edit_rounded, size: 14, color: Color(0xFF60A5FA)),
                  label: const Text('Edit', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 12)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                ),
                TextButton.icon(
                  onPressed: () => onDelete((s['id'] as num).toInt()),
                  icon: const Icon(Icons.delete_rounded, size: 14, color: AppColors.error),
                  label: const Text('Delete', style: TextStyle(color: AppColors.error, fontSize: 12)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                ),
              ]),
            ],
          ]),
        );
      },
    );
  }
}

// Helper widgets
class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  const _DropdownField({required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      dropdownColor: AppColors.surface,
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        filled: true, fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent)),
      ),
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    );
  }
}

class _NumField extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _NumField({required this.label, required this.value, required this.onChanged});
  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late final TextEditingController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = TextEditingController(text: widget.value.toStringAsFixed(0)); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => TextField(
    controller: _ctrl, keyboardType: TextInputType.number,
    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
    decoration: InputDecoration(
      labelText: widget.label, labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      filled: true, fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
    ),
    onChanged: (v) => widget.onChanged(double.tryParse(v) ?? 0),
  );
}
