import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/utils/error_handler.dart';
import '../../../shared/widgets/drawer_menu_button.dart';

class StaffAttendanceScreen extends ConsumerStatefulWidget {
  const StaffAttendanceScreen({super.key});

  @override
  ConsumerState<StaffAttendanceScreen> createState() =>
      _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState
    extends ConsumerState<StaffAttendanceScreen> {
  bool _loading = true;
  bool _acting = false;
  String? _error;
  Map<String, dynamic>? _myAttendance;
  List<Map<String, dynamic>> _history = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(apiRepositoryProvider);
      Map<String, dynamic>? mine;
      try {
        final meRes = await repo.getMyAttendance(gymId);
        if (meRes?['attendance'] is Map) {
          mine = Map<String, dynamic>.from(meRes!['attendance'] as Map);
        }
      } catch (_) {}
      final rows = await repo.getAttendanceHistory(gymId);
      if (!mounted) return;
      setState(() {
        _myAttendance = mine;
        _history = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.parse(e);
        _loading = false;
      });
    }
  }

  Future<void> _toggleAttendance(bool isCheckIn) async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    setState(() => _acting = true);
    try {
      final repo = ref.read(apiRepositoryProvider);
      if (isCheckIn) {
        await repo.staffCheckIn(gymId, locationName: 'FitFlow Admin');
      } else {
        await repo.staffCheckOut(gymId, locationName: 'FitFlow Admin');
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCheckIn ? 'Berhasil check-in staf' : 'Berhasil check-out staf'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.parse(e)), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  String _fmtTime(dynamic iso) {
    if (iso == null) return '-';
    final dt = DateTime.tryParse(iso.toString());
    if (dt == null) return '-';
    return DateFormat('HH:mm').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasCheckedIn = _myAttendance != null;
    final hasCheckedOut = _myAttendance?['checkOutTime'] != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: Text(l10n.menuStaffAttendance),
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.card,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
            : _error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 100),
                      Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Absensi Saya Hari Ini',
                              style: GoogleFonts.figtree(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              !hasCheckedIn
                                  ? 'Belum check-in hari ini'
                                  : hasCheckedOut
                                      ? 'Masuk ${_fmtTime(_myAttendance?['checkInTime'])} • Pulang ${_fmtTime(_myAttendance?['checkOutTime'])}'
                                      : 'Sedang bertugas sejak ${_fmtTime(_myAttendance?['checkInTime'])}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            if (!hasCheckedOut) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _acting
                                      ? null
                                      : () => _toggleAttendance(!hasCheckedIn),
                                  icon: Icon(
                                    hasCheckedIn
                                        ? LucideIcons.logOut
                                        : LucideIcons.logIn,
                                    size: 16,
                                  ),
                                  label: Text(
                                    _acting
                                        ? 'Memproses...'
                                        : (hasCheckedIn
                                            ? 'Check-Out Staf'
                                            : 'Check-In Staf'),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'RIWAYAT KEHADIRAN STAF',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_history.isEmpty)
                        const Text(
                          'Belum ada riwayat kehadiran staf',
                          style: TextStyle(color: AppColors.textMuted),
                        )
                      else
                        ..._history.map((row) {
                          final adminMap = row['Admin'] as Map?;
                          final trainerMap = row['Trainer'] as Map?;
                          final staffName = adminMap?['name'] as String? ??
                              adminMap?['email'] as String? ??
                              trainerMap?['name'] as String? ??
                              'Staf';
                          final role = adminMap != null
                              ? ((adminMap['role'] as String?) ?? 'admin')
                              : 'trainer';
                          final date = row['date'] as String? ?? '-';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        staffName,
                                        style: GoogleFonts.figtree(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$role • $date',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${_fmtTime(row['checkInTime'])} - ${_fmtTime(row['checkOutTime'])}',
                                  style: GoogleFonts.figtree(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
      ),
    );
  }
}
