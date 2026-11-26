import 'dart:async';
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

class PayslipsScreen extends ConsumerStatefulWidget {
  const PayslipsScreen({super.key});

  @override
  ConsumerState<PayslipsScreen> createState() => _PayslipsScreenState();
}

class _PayslipsScreenState extends ConsumerState<PayslipsScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _payslips = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiRepositoryProvider).getPayslips(
            gymId,
            search: _searchCtrl.text,
          );
      final rows = res['data'] as List? ?? const [];
      if (!mounted) return;
      setState(() {
        _payslips =
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: Text(l10n.menuPayslips),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), _load);
              },
              decoration: const InputDecoration(
                hintText: 'Cari nama penerima atau nomor slip...',
                prefixIcon: Icon(LucideIcons.search, size: 18),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.card,
              onRefresh: _load,
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    )
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
                      : _payslips.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 120),
                                Center(
                                  child: Text(
                                    'Belum ada slip gaji tersedia',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _payslips.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, idx) {
                                final p = _payslips[idx];
                                final netPay =
                                    ((p['netPay'] as num?) ?? 0).toDouble();
                                final grossPay =
                                    ((p['grossPay'] as num?) ?? 0).toDouble();
                                final status = p['status'] as String? ?? 'DRAFT';
                                final runTitle = (p['PayrollRun']
                                        as Map?)?['title'] as String? ??
                                    '-';
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.card,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              p['recipientName'] as String? ??
                                                  '-',
                                              style: GoogleFonts.figtree(
                                                color: AppColors.textPrimary,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            status,
                                            style: TextStyle(
                                              color: status == 'PAID'
                                                  ? AppColors.success
                                                  : AppColors.accent,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${p['slipNumber'] ?? '-'} • $runTitle',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Text(
                                            'Take Home: ${formatCurrency(netPay)}',
                                            style: GoogleFonts.figtree(
                                              color: AppColors.accent,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            'Gross: ${formatCurrency(grossPay)}',
                                            style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}
