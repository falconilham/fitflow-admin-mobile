import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/utils/error_handler.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/drawer_menu_button.dart';

class CashShiftsScreen extends ConsumerStatefulWidget {
  const CashShiftsScreen({super.key});

  @override
  ConsumerState<CashShiftsScreen> createState() => _CashShiftsScreenState();
}

class _CashShiftsScreenState extends ConsumerState<CashShiftsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _activeShift;
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
      final currentRes = await repo.getCurrentCashShift(gymId);
      final histRes = await repo.getCashShifts(gymId);
      final hasActive = currentRes['hasActiveShift'] == true;
      final rows = histRes['shifts'] as List? ??
          histRes['data'] as List? ??
          const [];
      if (!mounted) return;
      setState(() {
        _activeShift = hasActive && currentRes['shift'] is Map
            ? Map<String, dynamic>.from(currentRes['shift'] as Map)
            : null;
        _history =
            rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  Future<void> _openShiftDialog() async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    final cashCtrl = TextEditingController(text: '200000');
    final notesCtrl = TextEditingController();
    var saving = false;

    final done = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Buka Shift Kasir'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: cashCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Modal Awal (Rp)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(ctx);
                      setModalState(() => saving = true);
                      try {
                        await ref.read(apiRepositoryProvider).openCashShift(
                              gymId,
                              startingCash:
                                  int.tryParse(cashCtrl.text.trim()) ?? 0,
                              notes: notesCtrl.text.trim(),
                            );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setModalState(() => saving = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(ErrorHandler.parse(e)),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
              child: Text(saving ? 'Memproses...' : 'Buka Shift'),
            ),
          ],
        ),
      ),
    );

    cashCtrl.dispose();
    notesCtrl.dispose();
    if (done == true) await _load();
  }

  Future<void> _closeShiftDialog(Map<String, dynamic> shift) async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    final expected = (shift['currentExpectedCash'] as num?)?.toInt() ?? 0;
    final actualCtrl = TextEditingController(text: '$expected');
    final notesCtrl = TextEditingController();
    var saving = false;

    final done = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Tutup Shift & Rekonsiliasi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kas diharapkan sistem: ${formatCurrency(expected.toDouble())}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: actualCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Uang Fisik Aktual (Rp)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration:
                    const InputDecoration(labelText: 'Catatan Serah Terima'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(ctx);
                      setModalState(() => saving = true);
                      try {
                        await ref.read(apiRepositoryProvider).closeCashShift(
                              gymId,
                              actualCash:
                                  int.tryParse(actualCtrl.text.trim()) ?? 0,
                              shiftId: (shift['id'] as num?)?.toInt(),
                              handoverNotes: notesCtrl.text.trim(),
                            );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setModalState(() => saving = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(ErrorHandler.parse(e)),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
              child: Text(saving ? 'Menutup...' : 'Tutup Shift'),
            ),
          ],
        ),
      ),
    );

    actualCtrl.dispose();
    notesCtrl.dispose();
    if (done == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: Text(l10n.menuCashShifts),
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
                          color: _activeShift != null
                              ? AppColors.accentPill
                              : AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _activeShift != null
                                ? AppColors.accent
                                : AppColors.border,
                          ),
                        ),
                        child: _activeShift == null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tidak ada shift kasir aktif',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Buka shift baru sebelum menerima pembayaran tunai di kasir.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _openShiftDialog,
                                      icon: const Icon(LucideIcons.unlock, size: 16),
                                      label: const Text('Buka Shift Baru'),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.banknote,
                                        color: AppColors.accent,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Shift Aktif (#${_activeShift!['id']})',
                                        style: GoogleFonts.figtree(
                                          color: AppColors.accent,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Kasir: ${_activeShift!['cashierName'] ?? '-'}',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Kas Diharapkan: ${formatCurrency(((_activeShift!['currentExpectedCash'] as num?) ?? 0).toDouble())}',
                                    style: GoogleFonts.figtree(
                                      color: AppColors.textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tunai masuk: ${formatCurrency(((_activeShift!['currentCashPayments'] as num?) ?? 0).toDouble())} • '
                                    'Non-tunai: ${formatCurrency(((_activeShift!['currentNonCashPayments'] as num?) ?? 0).toDouble())}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _closeShiftDialog(_activeShift!),
                                      icon: const Icon(LucideIcons.lock, size: 16),
                                      label: const Text('Tutup Shift Kasir'),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'RIWAYAT SHIFT KASIR',
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
                          'Belum ada riwayat shift kasir',
                          style: TextStyle(color: AppColors.textMuted),
                        )
                      else
                        ..._history.map((s) {
                          final status = s['status'] as String? ?? 'CLOSED';
                          final expected =
                              ((s['expectedCash'] as num?) ?? 0).toDouble();
                          final actual =
                              ((s['actualCash'] as num?) ?? 0).toDouble();
                          final diff =
                              ((s['difference'] as num?) ?? 0).toDouble();
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Shift #${s['id']} • ${s['cashierName'] ?? '-'}',
                                      style: GoogleFonts.figtree(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      status,
                                      style: TextStyle(
                                        color: status == 'OPEN'
                                            ? AppColors.accent
                                            : AppColors.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Aktual ${formatCurrency(actual)} / Sistem ${formatCurrency(expected)} '
                                  '(Selisih ${formatCurrency(diff)})',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
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
