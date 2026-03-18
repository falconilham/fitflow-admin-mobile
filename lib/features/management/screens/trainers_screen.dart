import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/drawer_menu_button.dart';

final _trainersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return [];
  try {
    return await ref.read(apiRepositoryProvider).getTrainers(gymId);
  } on DioException catch (e) {
    if (e.response?.statusCode == 403 || e.response?.statusCode == 404) return [];
    rethrow;
  }
});

class TrainersScreen extends ConsumerStatefulWidget {
  const TrainersScreen({super.key});

  @override
  ConsumerState<TrainersScreen> createState() => _TrainersScreenState();
}

class _TrainersScreenState extends ConsumerState<TrainersScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _specialtyCtrl = TextEditingController();
  final _singlePriceCtrl = TextEditingController();
  final _pkgPriceCtrl = TextEditingController();
  final _pkgCountCtrl = TextEditingController(text: '10');
  final _commissionCtrl = TextEditingController(text: '0');
  bool _submitting = false;
  int? _editingId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _specialtyCtrl.dispose();
    _singlePriceCtrl.dispose();
    _pkgPriceCtrl.dispose();
    _pkgCountCtrl.dispose();
    _commissionCtrl.dispose();
    super.dispose();
  }

  void _showForm([Map<String, dynamic>? trainer]) {
    if (trainer != null) {
      _editingId = trainer['id'] as int?;
      _nameCtrl.text = (trainer['name'] ?? '').toString();
      _specialtyCtrl.text = (trainer['specialty'] ?? '').toString();
      _singlePriceCtrl.text = (trainer['singleSessionPrice'] ?? trainer['single_session_price'] ?? 0).toString();
      _pkgPriceCtrl.text = (trainer['packagePrice'] ?? trainer['package_price'] ?? 0).toString();
      _pkgCountCtrl.text = (trainer['packageCount'] ?? trainer['package_count'] ?? 10).toString();
      _commissionCtrl.text = (trainer['commissionPercentage'] ?? trainer['commission_percentage'] ?? 0).toString();
    } else {
      _editingId = null;
      _nameCtrl.clear();
      _specialtyCtrl.clear();
      _singlePriceCtrl.text = '0';
      _pkgPriceCtrl.text = '0';
      _pkgCountCtrl.text = '10';
      _commissionCtrl.text = '0';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_editingId != null ? 'Edit Trainer' : 'Add Trainer',
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 16),
            TextFormField(controller: _nameCtrl, style: const TextStyle(color: AppColors.textPrimary),
              decoration: _decor('Name'), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
            const SizedBox(height: 10),
            TextFormField(controller: _specialtyCtrl, style: const TextStyle(color: AppColors.textPrimary),
              decoration: _decor('Specialty (e.g. Yoga, CrossFit)'), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(controller: _singlePriceCtrl, keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary), decoration: _decor('Single Session Price (IDR)'))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _commissionCtrl, keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary), decoration: _decor('Commission %'))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(controller: _pkgPriceCtrl, keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary), decoration: _decor('Package Price (IDR)'))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _pkgCountCtrl, keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary), decoration: _decor('Sessions in Package'))),
            ]),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _submitting ? null : () => _submit(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _submitting
                ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.black)
                : Text(_editingId != null ? 'Update' : 'Add Trainer', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
            )),
          ])),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext ctx) async {
    if (!_formKey.currentState!.validate()) return;
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    setState(() => _submitting = true);
    try {
      final data = {
        'name': _nameCtrl.text.trim(),
        'specialty': _specialtyCtrl.text.trim(),
        'singleSessionPrice': double.tryParse(_singlePriceCtrl.text) ?? 0,
        'packagePrice': double.tryParse(_pkgPriceCtrl.text) ?? 0,
        'packageCount': int.tryParse(_pkgCountCtrl.text) ?? 10,
        'commissionPercentage': double.tryParse(_commissionCtrl.text) ?? 0,
      };
      if (_editingId != null) {
        await ref.read(apiRepositoryProvider).updateTrainer(_editingId!, gymId, data);
      } else {
        await ref.read(apiRepositoryProvider).createTrainer(gymId, data);
      }
      ref.invalidate(_trainersProvider);
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
      title: const Text('Delete Trainer?', style: TextStyle(color: AppColors.textPrimary)),
      content: const Text('This action cannot be undone.', style: TextStyle(color: AppColors.textMuted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
      ],
    ));
    if (confirm != true) return;
    try {
      await ref.read(apiRepositoryProvider).deleteTrainer(id);
      ref.invalidate(_trainersProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  InputDecoration _decor(String label) => InputDecoration(
    labelText: label, labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
    filled: true, fillColor: AppColors.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent)),
  );

  @override
  Widget build(BuildContext context) {
    final trAsync = ref.watch(_trainersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Trainers', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add_rounded, color: Colors.black),
      ),
      body: trAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
        error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.error))),
        data: (list) {
          if (list.isEmpty) {
            return RefreshIndicator(
              color: AppColors.accent, backgroundColor: AppColors.card,
              onRefresh: () async => ref.invalidate(_trainersProvider),
              child: ListView(children: const [
                SizedBox(height: 200),
                Center(child: Text('No trainers yet. Tap + to add.', style: TextStyle(color: AppColors.textMuted))),
              ]),
            );
          }
          return RefreshIndicator(
            color: AppColors.accent, backgroundColor: AppColors.card,
            onRefresh: () async => ref.invalidate(_trainersProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final t = list[i];
                final name = (t['name'] ?? 'Unknown').toString();
                final specialty = (t['specialty'] ?? '').toString();
                final singlePrice = (t['singleSessionPrice'] ?? t['single_session_price'] ?? 0) as num;
                final pkgPrice = (t['packagePrice'] ?? t['package_price'] ?? 0) as num;
                final pkgCount = (t['packageCount'] ?? t['package_count'] ?? 0) as num;
                final rating = (t['rating'] ?? 0) as num;
                final initials = name.split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase();

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF60A5FA).withAlpha(30),
                        radius: 24,
                        child: Text(initials, style: const TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (specialty.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFF60A5FA).withAlpha(25), borderRadius: BorderRadius.circular(8)),
                            child: Text(specialty, style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                      ])),
                      if (rating > 0) Row(children: [
                        const Icon(Icons.star_rounded, color: AppColors.accent, size: 14),
                        const SizedBox(width: 2),
                        Text(rating.toStringAsFixed(1), style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 12)),
                      ]),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        color: AppColors.surface,
                        icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 20),
                        onSelected: (v) {
                          if (v == 'edit') _showForm(t);
                          if (v == 'delete') _delete((t['id'] as num).toInt());
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, color: AppColors.textMuted, size: 16), SizedBox(width: 8), Text('Edit', style: TextStyle(color: AppColors.textPrimary))])),
                          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, color: AppColors.error, size: 16), SizedBox(width: 8), Text('Delete', style: TextStyle(color: AppColors.error))])),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _PriceCell(label: 'Single', value: formatCurrency(singlePrice.toDouble()))),
                      Expanded(child: _PriceCell(label: 'Package ($pkgCount sess)', value: formatCurrency(pkgPrice.toDouble()))),
                    ]),
                  ]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _PriceCell extends StatelessWidget {
  final String label;
  final String value;
  const _PriceCell({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
    Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
  ]);
}
