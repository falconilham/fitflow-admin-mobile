import 'dart:async';

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

class _TxFilters {
  final int gymId;
  final String search;
  final String? startDate;
  final String? endDate;
  final String type; // ALL | MEMBERSHIP_NEW | MEMBERSHIP_EXTENSION | SESSION_BOOKING | PACKAGE_PURCHASE | OTHER | EXPENSE
  final String paymentMethod; // ALL | Cash | Transfer | QR
  final String status; // active | archived | all
  final int page;
  final int limit;

  const _TxFilters({
    required this.gymId,
    this.search = '',
    this.startDate,
    this.endDate,
    this.type = 'ALL',
    this.paymentMethod = 'ALL',
    this.status = 'active',
    this.page = 1,
    this.limit = 25,
  });

  @override
  bool operator ==(Object other) =>
      other is _TxFilters &&
      other.gymId == gymId &&
      other.search == search &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.type == type &&
      other.paymentMethod == paymentMethod &&
      other.status == status &&
      other.page == page &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(gymId, search, startDate, endDate, type,
      paymentMethod, status, page, limit);
}

final _txProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, _TxFilters>(
        (ref, f) async {
  try {
    return await ref.read(apiRepositoryProvider).getRevenueDetails(
          f.gymId,
          search: f.search.isEmpty ? null : f.search,
          startDate: f.startDate,
          endDate: f.endDate,
          type: f.type,
          paymentMethod: f.paymentMethod,
          status: f.status,
          page: f.page,
          limit: f.limit,
        );
  } on DioException catch (e) {
    if (e.response?.statusCode == 403 || e.response?.statusCode == 404) {
      return {};
    }
    rethrow;
  }
});

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  String _search = '';
  DateTime? _start;
  DateTime? _end;
  String _type = 'ALL';
  String _paymentMethod = 'ALL';
  String _status = 'active';
  int _page = 1;
  static const _limit = 25;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _search = v.trim();
        _page = 1;
      });
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
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
    if (picked != null) {
      setState(() {
        _start = picked;
        if (_end != null && _end!.isBefore(picked)) _end = picked;
        _page = 1;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end ?? _start ?? DateTime.now(),
      firstDate: _start ?? DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
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
    if (picked != null) {
      setState(() {
        _end = picked;
        _page = 1;
      });
    }
  }

  void _clearDates() {
    setState(() {
      _start = null;
      _end = null;
      _page = 1;
    });
  }

  String? get _startIso {
    if (_start == null) return null;
    final d = DateTime(_start!.year, _start!.month, _start!.day, 0, 0, 0);
    return d.toUtc().toIso8601String();
  }

  String? get _endIso {
    if (_end == null) return null;
    final d = DateTime(_end!.year, _end!.month, _end!.day, 23, 59, 59, 999);
    return d.toUtc().toIso8601String();
  }

  Future<void> _archive(Map<String, dynamic> tx) async {
    final isExpense = _isExpense(tx);
    final typeLabel = isExpense ? 'Expense' : 'Transaction';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Archive $typeLabel?',
            style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Yakin ingin mengarsipkan $typeLabel ini? Tidak akan dihitung di total keuangan.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final id = _cleanId(tx);
    if (id == null) return;

    try {
      final repo = ref.read(apiRepositoryProvider);
      if (isExpense) {
        await repo.archiveExpense(id);
      } else {
        await repo.archiveTransaction(id);
      }
      _invalidate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berhasil diarsipkan')),
        );
      }
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

  Future<void> _restore(Map<String, dynamic> tx) async {
    final id = _cleanId(tx);
    if (id == null) return;
    final isExpense = _isExpense(tx);
    try {
      final repo = ref.read(apiRepositoryProvider);
      if (isExpense) {
        await repo.restoreExpense(id);
      } else {
        await repo.restoreTransaction(id);
      }
      _invalidate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berhasil dipulihkan')),
        );
      }
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

  void _invalidate() {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    ref.invalidate(_txProvider(_currentFilters(gymId)));
  }

  _TxFilters _currentFilters(int gymId) => _TxFilters(
        gymId: gymId,
        search: _search,
        startDate: _startIso,
        endDate: _endIso,
        type: _type,
        paymentMethod: _paymentMethod,
        status: _status,
        page: _page,
        limit: _limit,
      );

  bool _isExpense(Map<String, dynamic> tx) {
    if (tx['isExpense'] == true) return true;
    final id = tx['id'];
    return id is String && id.startsWith('EXP-');
  }

  // Returns the integer ID (strips EXP- prefix for expenses)
  int? _cleanId(Map<String, dynamic> tx) {
    final id = tx['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    if (id is String) {
      final s = id.startsWith('EXP-') ? id.substring(4) : id;
      return int.tryParse(s);
    }
    return null;
  }

  String _typeLabel(Map<String, dynamic> tx) {
    if (_isExpense(tx)) {
      return (tx['category'] as String?) ?? 'Expense';
    }
    final t = tx['type'] as String? ?? '';
    switch (t) {
      case 'MEMBERSHIP_NEW':
        return 'Membership Baru';
      case 'MEMBERSHIP_EXTENSION':
        return 'Perpanjangan';
      case 'SESSION_BOOKING':
        return 'PT Session';
      case 'PACKAGE_PURCHASE':
        return 'Paket Trainer';
      case 'OTHER':
        return 'POS / Lainnya';
      default:
        return t.isEmpty ? 'Lainnya' : t;
    }
  }

  Color _typeColor(Map<String, dynamic> tx) {
    if (_isExpense(tx)) return AppColors.error;
    final t = tx['type'] as String? ?? '';
    switch (t) {
      case 'MEMBERSHIP_NEW':
        return const Color(0xFF4ADE80);
      case 'MEMBERSHIP_EXTENSION':
        return const Color(0xFF60A5FA);
      case 'SESSION_BOOKING':
        return const Color(0xFFF472B6);
      case 'PACKAGE_PURCHASE':
        return const Color(0xFFC084FC);
      default:
        return const Color(0xFFFBBF24);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Transactions',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
            onPressed: gymId == null ? null : _invalidate,
          ),
        ],
      ),
      body: gymId == null
          ? const Center(
              child: Text('Pilih gym terlebih dahulu',
                  style: TextStyle(color: AppColors.textMuted)))
          : Column(
              children: [
                _buildFilters(),
                Expanded(child: _buildList(gymId)),
              ],
            ),
    );
  }

  Widget _buildFilters() {
    final df = DateFormat('d MMM yy', 'id_ID');
    final dateLabel = _start != null && _end != null
        ? '${df.format(_start!)} – ${df.format(_end!)}'
        : _start != null
            ? 'Mulai ${df.format(_start!)}'
            : _end != null
                ? 'S/d ${df.format(_end!)}'
                : 'Tanggal';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Cari nama member, tipe, ref...',
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textMuted, size: 20),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textMuted, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearchChanged('');
                      },
                    ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          // Filter chips row 1: date + status
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Date range
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    await showModalBottomSheet(
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
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('Filter Tanggal',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  )),
                              const SizedBox(height: 16),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Tanggal Mulai',
                                    style:
                                        TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                subtitle: Text(
                                  _start != null
                                      ? DateFormat('d MMM yyyy', 'id_ID').format(_start!)
                                      : 'Belum dipilih',
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600),
                                ),
                                trailing: const Icon(Icons.calendar_today_rounded,
                                    color: AppColors.accent, size: 18),
                                onTap: () async {
                                  Navigator.pop(context);
                                  await _pickStartDate();
                                },
                              ),
                              const Divider(color: AppColors.border, height: 1),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Tanggal Akhir',
                                    style:
                                        TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                subtitle: Text(
                                  _end != null
                                      ? DateFormat('d MMM yyyy', 'id_ID').format(_end!)
                                      : 'Belum dipilih',
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600),
                                ),
                                trailing: const Icon(Icons.calendar_today_rounded,
                                    color: AppColors.accent, size: 18),
                                onTap: () async {
                                  Navigator.pop(context);
                                  await _pickEndDate();
                                },
                              ),
                              const SizedBox(height: 12),
                              if (_start != null || _end != null)
                                TextButton.icon(
                                  icon: const Icon(Icons.clear_rounded,
                                      color: AppColors.error, size: 18),
                                  label: const Text('Reset Tanggal',
                                      style: TextStyle(color: AppColors.error)),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _clearDates();
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (_start != null || _end != null)
                          ? AppColors.accent.withAlpha(30)
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: (_start != null || _end != null)
                              ? AppColors.accent
                              : AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_rounded,
                            size: 14,
                            color: (_start != null || _end != null)
                                ? AppColors.accent
                                : AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(dateLabel,
                            style: TextStyle(
                              color: (_start != null || _end != null)
                                  ? AppColors.accent
                                  : AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Type filter
                _DropdownChip(
                  icon: Icons.category_rounded,
                  label: _typeFilterLabel(_type),
                  isActive: _type != 'ALL',
                  onTap: () => _showTypePicker(),
                ),
                const SizedBox(width: 8),
                // Payment method filter
                _DropdownChip(
                  icon: Icons.payments_rounded,
                  label: _paymentMethod == 'ALL' ? 'Pembayaran' : _paymentMethod,
                  isActive: _paymentMethod != 'ALL',
                  onTap: () => _showPaymentPicker(),
                ),
                const SizedBox(width: 8),
                // Status filter
                _DropdownChip(
                  icon: Icons.layers_rounded,
                  label: _statusLabel(_status),
                  isActive: _status != 'active',
                  onTap: () => _showStatusPicker(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _typeFilterLabel(String t) {
    switch (t) {
      case 'MEMBERSHIP_NEW':
        return 'Membership Baru';
      case 'MEMBERSHIP_EXTENSION':
        return 'Perpanjangan';
      case 'SESSION_BOOKING':
        return 'PT Session';
      case 'OTHER':
        return 'POS';
      case 'EXPENSE':
        return 'Expense';
      default:
        return 'Tipe';
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'archived':
        return 'Archived';
      case 'all':
        return 'Semua Status';
      default:
        return 'Aktif';
    }
  }

  void _showTypePicker() {
    _showOptionSheet(
      title: 'Tipe Transaksi',
      options: const [
        _Opt('ALL', 'Semua Tipe'),
        _Opt('MEMBERSHIP_NEW', 'Membership Baru'),
        _Opt('MEMBERSHIP_EXTENSION', 'Perpanjangan'),
        _Opt('SESSION_BOOKING', 'PT Session'),
        _Opt('OTHER', 'POS / Penjualan Produk'),
        _Opt('EXPENSE', 'Expense / Pengeluaran'),
      ],
      current: _type,
      onPick: (v) => setState(() {
        _type = v;
        _page = 1;
      }),
    );
  }

  void _showPaymentPicker() {
    _showOptionSheet(
      title: 'Metode Pembayaran',
      options: const [
        _Opt('ALL', 'Semua'),
        _Opt('Cash', 'Cash'),
        _Opt('Transfer', 'Transfer'),
        _Opt('QR', 'QR'),
      ],
      current: _paymentMethod,
      onPick: (v) => setState(() {
        _paymentMethod = v;
        _page = 1;
      }),
    );
  }

  void _showStatusPicker() {
    _showOptionSheet(
      title: 'Status',
      options: const [
        _Opt('active', 'Aktif'),
        _Opt('archived', 'Archived'),
        _Opt('all', 'Semua Status'),
      ],
      current: _status,
      onPick: (v) => setState(() {
        _status = v;
        _page = 1;
      }),
    );
  }

  void _showOptionSheet({
    required String title,
    required List<_Opt> options,
    required String current,
    required ValueChanged<String> onPick,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
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
                        onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(color: AppColors.border, height: 1),
              ...options.map((opt) {
                final selected = opt.value == current;
                return ListTile(
                  title: Text(opt.label,
                      style: TextStyle(
                        color: selected
                            ? AppColors.accent
                            : AppColors.textPrimary,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      )),
                  trailing: selected
                      ? const Icon(Icons.check_rounded, color: AppColors.accent)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    onPick(opt.value);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(int gymId) {
    final f = _currentFilters(gymId);
    final dataAsync = ref.watch(_txProvider(f));

    return dataAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(ErrorHandler.parse(e),
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center),
        ),
      ),
      data: (data) {
        if (data.isEmpty) {
          return const Center(
            child: Text(
              'Tidak ada akses atau data.\nButuh permission Owner / Finance.',
              style: TextStyle(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          );
        }

        final summary = (data['summary'] as Map?)?.cast<String, dynamic>() ?? {};
        final pagination = (data['pagination'] as Map?)?.cast<String, dynamic>() ?? {};
        final list = (data['transactions'] as List?)?.cast<dynamic>() ?? [];

        final grossProfit =
            ((summary['gross_profit'] ?? 0) as num).toDouble();
        final expenses = ((summary['expenses'] ?? 0) as num).toDouble();
        final netProfit = ((summary['net_profit'] ?? 0) as num).toDouble();
        final netCash = ((summary['net_cash'] ?? 0) as num).toDouble();
        final netAccount = ((summary['net_account'] ?? 0) as num).toDouble();

        final totalItems = (pagination['totalItems'] as num?)?.toInt() ?? list.length;
        final totalPages = (pagination['totalPages'] as num?)?.toInt() ?? 1;
        final currentPage = (pagination['currentPage'] as num?)?.toInt() ?? _page;

        return RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.card,
          onRefresh: () async => _invalidate(),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Summary cards
              _SummaryGrid(
                grossProfit: grossProfit,
                expenses: expenses,
                netProfit: netProfit,
                netCash: netCash,
                netAccount: netAccount,
              ),
              const SizedBox(height: 8),
              // Count info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  '$totalItems transaksi • Halaman $currentPage / $totalPages',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_rounded,
                            size: 56, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Text('Tidak ada transaksi sesuai filter.',
                            style: TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                )
              else
                ...list.map((raw) {
                  final tx = (raw as Map).cast<String, dynamic>();
                  return _TransactionCard(
                    tx: tx,
                    isExpense: _isExpense(tx),
                    typeLabel: _typeLabel(tx),
                    typeColor: _typeColor(tx),
                    onTap: () => _openDetail(tx),
                    onArchive: () => _archive(tx),
                    onRestore: () => _restore(tx),
                  );
                }),
              const SizedBox(height: 12),
              // Pagination
              if (totalPages > 1)
                _Paginator(
                  currentPage: currentPage,
                  totalPages: totalPages,
                  onPrev: currentPage > 1
                      ? () => setState(() => _page = currentPage - 1)
                      : null,
                  onNext: currentPage < totalPages
                      ? () => setState(() => _page = currentPage + 1)
                      : null,
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // Open detail in a draggable bottom sheet
  void _openDetail(Map<String, dynamic> tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _TransactionDetailSheet(
        tx: tx,
        isExpense: _isExpense(tx),
        typeLabel: _typeLabel(tx),
        typeColor: _typeColor(tx),
        onArchive: () {
          Navigator.pop(sheetCtx);
          _archive(tx);
        },
        onRestore: () {
          Navigator.pop(sheetCtx);
          _restore(tx);
        },
      ),
    );
  }
}

class _Opt {
  final String value;
  final String label;
  const _Opt(this.value, this.label);
}

class _DropdownChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _DropdownChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent.withAlpha(30) : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive ? AppColors.accent : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: isActive ? AppColors.accent : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  color: isActive ? AppColors.accent : AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded,
                size: 16,
                color: isActive ? AppColors.accent : AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final double grossProfit;
  final double expenses;
  final double netProfit;
  final double netCash;
  final double netAccount;
  const _SummaryGrid({
    required this.grossProfit,
    required this.expenses,
    required this.netProfit,
    required this.netCash,
    required this.netAccount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SumCard(
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF3B82F6),
                label: 'GROSS',
                value: formatCurrency(grossProfit),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SumCard(
                icon: Icons.trending_down_rounded,
                color: AppColors.error,
                label: 'EXPENSES',
                value: formatCurrency(expenses),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _SumCard(
          icon: Icons.account_balance_rounded,
          color: netProfit >= 0 ? AppColors.success : AppColors.error,
          label: 'NET PROFIT',
          value: formatCurrency(netProfit),
          big: true,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _SumCard(
                icon: Icons.payments_rounded,
                color: AppColors.success,
                label: 'NET CASH',
                value: formatCurrency(netCash),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SumCard(
                icon: Icons.credit_card_rounded,
                color: const Color(0xFFFBBF24),
                label: 'NET ACCOUNT',
                value: formatCurrency(netAccount),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SumCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool big;
  const _SumCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(big ? 16 : 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(big ? 10 : 8),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: big ? 22 : 18),
          ),
          SizedBox(width: big ? 12 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: big ? 11 : 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    )),
                SizedBox(height: big ? 4 : 2),
                Text(value,
                    style: TextStyle(
                      color: color,
                      fontSize: big ? 19 : 14,
                      fontWeight: FontWeight.w800,
                    ),
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

class _TransactionCard extends StatelessWidget {
  final Map<String, dynamic> tx;
  final bool isExpense;
  final String typeLabel;
  final Color typeColor;
  final VoidCallback onTap;
  final VoidCallback onArchive;
  final VoidCallback onRestore;

  const _TransactionCard({
    required this.tx,
    required this.isExpense,
    required this.typeLabel,
    required this.typeColor,
    required this.onTap,
    required this.onArchive,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final amount = ((tx['amount'] ?? 0) as num).toDouble();
    final paymentMethod = tx['paymentMethod'] as String? ?? '-';
    final memberName = tx['memberName'] as String?;
    final refId = tx['referenceId']?.toString();
    final tsRaw =
        (tx['timestamp'] ?? tx['displayDate'] ?? tx['date'])?.toString();
    final isArchived = (tx['status'] as String?) == 'Deleted';
    final items = (tx['items'] as List?)?.length ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isArchived
                ? AppColors.error.withAlpha(80)
                : AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: typeColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          typeLabel.toUpperCase(),
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        (isExpense ? '- ' : '+ ') + formatCurrency(amount),
                        style: TextStyle(
                          color: isExpense
                              ? AppColors.error
                              : const Color(0xFF4ADE80),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    memberName ??
                        (refId != null ? '#$refId' : 'Internal Transaction'),
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tsRaw != null ? formatDateTime(tsRaw) : '-',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          paymentMethod,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  if (items > 0 || isArchived) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (items > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$items item${items == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        if (isArchived)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.error.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ARCHIVED',
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Action row — View Detail + Archive/Restore
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.visibility_rounded,
                        size: 16, color: AppColors.accent),
                    label: const Text('View Detail',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        )),
                  ),
                ),
                Container(width: 1, height: 30, color: AppColors.border),
                if (isArchived)
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onRestore,
                      icon: const Icon(Icons.restore_rounded,
                          size: 16, color: AppColors.success),
                      label: const Text('Restore',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          )),
                    ),
                  )
                else
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onArchive,
                      icon: const Icon(Icons.archive_rounded,
                          size: 16, color: AppColors.error),
                      label: const Text('Archive',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          )),
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

// ─── Detail Bottom Sheet ──────────────────────────────────────────────────
class _TransactionDetailSheet extends StatelessWidget {
  final Map<String, dynamic> tx;
  final bool isExpense;
  final String typeLabel;
  final Color typeColor;
  final VoidCallback onArchive;
  final VoidCallback onRestore;

  const _TransactionDetailSheet({
    required this.tx,
    required this.isExpense,
    required this.typeLabel,
    required this.typeColor,
    required this.onArchive,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final amount = ((tx['amount'] ?? 0) as num).toDouble();
    final memberName = tx['memberName'] as String?;
    final packageName = tx['packageName'] as String?;
    final refId = tx['referenceId']?.toString();
    final description = tx['description'] as String?;
    final category = tx['category'] as String?;
    final paymentMethod = tx['paymentMethod'] as String? ?? '-';
    final tsRaw =
        (tx['timestamp'] ?? tx['displayDate'] ?? tx['date'])?.toString();
    final trainerShare = (tx['trainerShare'] as num?)?.toDouble();
    final gymShare = (tx['gymShare'] as num?)?.toDouble();
    final commissionPct = (tx['commissionPercentage'] as num?)?.toInt();
    final items = (tx['items'] as List?)?.cast<dynamic>() ?? const [];
    final isArchived = (tx['status'] as String?) == 'Deleted';
    final adminName =
        (tx['Admin'] is Map ? tx['Admin']['name'] : null) as String?;
    final txId = tx['id']?.toString() ?? '-';

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: typeColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(typeLabel.toUpperCase(),
                        style: TextStyle(
                            color: typeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3)),
                  ),
                  const SizedBox(width: 8),
                  if (isArchived)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.error.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('ARCHIVED',
                          style: TextStyle(
                              color: AppColors.error,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                    ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Big amount + ID
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (isExpense ? '- ' : '+ ') + formatCurrency(amount),
                    style: TextStyle(
                      color:
                          isExpense ? AppColors.error : const Color(0xFF4ADE80),
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('ID #$txId',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                      if (tsRaw != null) ...[
                        const SizedBox(width: 8),
                        const Text('•',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                        const SizedBox(width: 8),
                        Text(formatDateTime(tsRaw),
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.border, height: 1),
            // Body — scrollable
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                children: [
                  // Detail card
                  _DetailBlock(
                    title: 'DETAIL TRANSAKSI',
                    rows: [
                      if (memberName != null)
                        _DetailRow(label: 'Member', value: memberName),
                      if (packageName != null)
                        _DetailRow(label: 'Paket', value: packageName),
                      if (refId != null)
                        _DetailRow(label: 'Reference ID', value: '#$refId'),
                      _DetailRow(label: 'Tipe', value: typeLabel),
                      _DetailRow(
                          label: 'Metode Pembayaran', value: paymentMethod),
                      if (tsRaw != null)
                        _DetailRow(
                            label: 'Waktu', value: formatDateTime(tsRaw)),
                      if (adminName != null)
                        _DetailRow(label: 'Oleh', value: adminName),
                      _DetailRow(
                        label: 'Total',
                        value: formatCurrency(amount),
                        valueColor: AppColors.accent,
                        bold: true,
                      ),
                    ],
                  ),

                  if (isExpense &&
                      (category != null || description != null)) ...[
                    const SizedBox(height: 12),
                    _DetailBlock(
                      title: 'EXPENSE',
                      rows: [
                        if (category != null)
                          _DetailRow(label: 'Kategori', value: category),
                        if (description != null)
                          _DetailRow(label: 'Deskripsi', value: description),
                      ],
                    ),
                  ],

                  // Trainer commission breakdown
                  if (trainerShare != null || gymShare != null) ...[
                    const SizedBox(height: 12),
                    _DetailBlock(
                      title: 'TRAINER COMMISSION',
                      rows: [
                        if (commissionPct != null)
                          _DetailRow(
                              label: 'Persentase Komisi',
                              value: '$commissionPct%'),
                        if (trainerShare != null)
                          _DetailRow(
                            label: 'Trainer Share',
                            value: formatCurrency(trainerShare),
                            valueColor: const Color(0xFF4ADE80),
                          ),
                        if (gymShare != null)
                          _DetailRow(
                            label: 'Gym Share',
                            value: formatCurrency(gymShare),
                            valueColor: const Color(0xFF60A5FA),
                          ),
                      ],
                    ),
                  ],

                  // POS items list
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ITEMS (${items.length})',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              )),
                          const SizedBox(height: 10),
                          // Header
                          const Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Text('PRODUK',
                                    style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('QTY',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700)),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text('SUBTOTAL',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Divider(color: AppColors.border, height: 1),
                          ...items.map((raw) {
                            final item = (raw as Map).cast<String, dynamic>();
                            final name =
                                item['productName'] as String? ?? 'Item';
                            final qty =
                                (item['quantity'] as num?)?.toInt() ?? 0;
                            final price =
                                (item['priceAtSale'] as num?)?.toDouble() ??
                                    0;
                            final subtotal =
                                (item['subtotal'] as num?)?.toDouble() ??
                                    price * qty;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(name,
                                            style: const TextStyle(
                                                color:
                                                    AppColors.textPrimary,
                                                fontSize: 12,
                                                fontWeight:
                                                    FontWeight.w600)),
                                        if (price > 0)
                                          Text(
                                            '@ ${formatCurrency(price)}',
                                            style: const TextStyle(
                                                color: AppColors.textMuted,
                                                fontSize: 10),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      qty.toString(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      formatCurrency(subtotal),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                          color: AppColors.accent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Bottom action bar
            Container(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Tutup'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: isArchived
                        ? ElevatedButton.icon(
                            onPressed: onRestore,
                            icon: const Icon(Icons.restore_rounded, size: 16),
                            label: const Text('Restore'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: onArchive,
                            icon: const Icon(Icons.archive_rounded, size: 16),
                            label: const Text('Archive'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  final String title;
  final List<_DetailRow> rows;
  const _DetailBlock({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              )),
          const SizedBox(height: 10),
          ...rows,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                  color: valueColor ?? AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                )),
          ),
        ],
      ),
    );
  }
}

class _Paginator extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  const _Paginator({
    required this.currentPage,
    required this.totalPages,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded),
          color: onPrev != null ? AppColors.accent : AppColors.textMuted,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            '$currentPage / $totalPages',
            style: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
          color: onNext != null ? AppColors.accent : AppColors.textMuted,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ],
    );
  }
}
