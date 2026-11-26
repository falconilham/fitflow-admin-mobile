import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/utils/error_handler.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/drawer_menu_button.dart';

class PayrollScreen extends ConsumerStatefulWidget {
  const PayrollScreen({super.key});

  @override
  ConsumerState<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends ConsumerState<PayrollScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _runs = const [];

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
      final res = await ref.read(apiRepositoryProvider).getPayrollRuns(gymId);
      final rows = res['data'] as List? ?? const [];
      if (!mounted) return;
      setState(() {
        _runs = rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  Future<void> _generateCurrentMonth() async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    final last = DateTime(now.year, now.month + 1, 0);
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    try {
      await ref.read(apiRepositoryProvider).generatePayrollRun(gymId, {
        'periodMonth': now.month,
        'periodYear': now.year,
        'startDate': fmt(first),
        'endDate': fmt(last),
        'title': 'Payroll ${now.month}/${now.year}',
      });
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft payroll bulan ini berhasil dibuat')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.parse(e)), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _approve(int id) async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    try {
      await ref.read(apiRepositoryProvider).approvePayrollRun(id, gymId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.parse(e)), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _pay(int id) async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    try {
      await ref.read(apiRepositoryProvider).payPayrollRun(id, gymId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.parse(e)), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: Text(l10n.menuPayroll),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.fileText, color: AppColors.textPrimary),
            tooltip: l10n.menuPayslips,
            onPressed: () => context.push(AppRoutes.payslips),
          ),
          IconButton(
            icon: const Icon(LucideIcons.plus, color: AppColors.accent),
            tooltip: 'Buat Payroll Bulan Ini',
            onPressed: _generateCurrentMonth,
          ),
        ],
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
                : _runs.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          const SizedBox(height: 80),
                          const Center(
                            child: Text(
                              'Belum ada riwayat penggajian (Payroll)',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: _generateCurrentMonth,
                              icon: const Icon(LucideIcons.plus, size: 16),
                              label: const Text('Generate Payroll Bulan Ini'),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _runs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, idx) {
                          final r = _runs[idx];
                          final id = (r['id'] as num).toInt();
                          final title = r['title'] as String? ?? 'Payroll #$id';
                          final status = r['status'] as String? ?? 'DRAFT';
                          final totalNet =
                              ((r['totalNet'] as num?) ?? 0).toDouble();
                          final staffCount =
                              (r['staffCount'] as num?)?.toInt() ?? 0;

                          return Container(
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
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: GoogleFonts.figtree(
                                          color: AppColors.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: status == 'PAID'
                                            ? AppColors.successPillBg
                                            : AppColors.accentPill,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          color: status == 'PAID'
                                              ? AppColors.successPillText
                                              : AppColors.accent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${formatCurrency(totalNet)} • $staffCount penerima',
                                  style: GoogleFonts.figtree(
                                    color: AppColors.accent,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (status != 'PAID') ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      if (status == 'DRAFT')
                                        OutlinedButton(
                                          onPressed: () => _approve(id),
                                          child: const Text('Setujui'),
                                        ),
                                      if (status == 'DRAFT')
                                        const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () => _pay(id),
                                        child: const Text('Bayar Sekarang'),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
