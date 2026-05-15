import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/drawer_menu_button.dart';
import '../../../shared/utils/error_handler.dart';

final _expensesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return [];
  try {
    return await ref.read(apiRepositoryProvider).getExpenses(gymId);
  } on DioException catch (e) {
    if (e.response?.statusCode == 403 || e.response?.statusCode == 404) return [];
    rethrow;
  }
});

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(apiRepositoryProvider).createExpense({
        'gymId': gymId,
        'name': _nameCtrl.text.trim(),
        'amount': double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0,
        'note': _noteCtrl.text.trim(),
      });
      _nameCtrl.clear(); _amountCtrl.clear(); _noteCtrl.clear();
      ref.invalidate(_expensesProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.parse(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Add Expense', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 16),
            TextFormField(controller: _nameCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: _inputDecor('Name / Description'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null),
            const SizedBox(height: 10),
            TextFormField(controller: _amountCtrl, keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: _inputDecor('Amount (IDR)'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null),
            const SizedBox(height: 10),
            TextFormField(controller: _noteCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: _inputDecor('Note (optional)'),
              maxLines: 2),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _submitting
                ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.black)
                : const Text('Add Expense', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
            )),
          ]),
        ),
      ),
    );
  }

  InputDecoration _inputDecor(String label) => InputDecoration(
    labelText: label, labelStyle: const TextStyle(color: AppColors.textMuted),
    filled: true, fillColor: AppColors.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent)),
  );

  @override
  Widget build(BuildContext context) {
    final expAsync = ref.watch(_expensesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Expenses', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add_rounded, color: Colors.black),
      ),
      body: expAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
        error: (e, _) => Center(child: Text(ErrorHandler.parse(e), style: const TextStyle(color: AppColors.error))),
        data: (list) {
          if (list.isEmpty) {
            return RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.card,
              onRefresh: () async => ref.invalidate(_expensesProvider),
              child: ListView(children: const [
                SizedBox(height: 200),
                Center(child: Text('No expenses yet.', style: TextStyle(color: AppColors.textMuted))),
              ]),
            );
          }

          final total = list.fold<double>(0, (sum, e) => sum + ((e['amount'] as num?) ?? 0).toDouble());

          return RefreshIndicator(
            color: AppColors.accent, backgroundColor: AppColors.card,
            onRefresh: () async => ref.invalidate(_expensesProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF87171).withAlpha(25),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF87171).withAlpha(75)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.money_off_rounded, color: Color(0xFFF87171), size: 28),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Total Expenses', style: TextStyle(color: Color(0xFFF87171), fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(formatCurrency(total), style: const TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.w800, fontSize: 22)),
                    ]),
                  ]),
                ),
                ...list.map((e) {
                  final name = e['name'] ?? e['description'] ?? 'Expense';
                  final amount = (e['amount'] as num? ?? 0).toDouble();
                  final note = e['note'] ?? '';
                  final date = e['createdAt'] ?? e['created_at'];
                  final dateStr = date != null ? formatDateTime(date.toString()) : '-';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Flexible(child: Text(name.toString(), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                        Text(formatCurrency(amount), style: const TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.w800)),
                      ]),
                      if (note != null && note.toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(note.toString(), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                      const SizedBox(height: 4),
                      Text(dateStr, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ]),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
