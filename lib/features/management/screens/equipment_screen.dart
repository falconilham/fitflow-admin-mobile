import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/drawer_menu_button.dart';
import '../../../shared/utils/error_handler.dart';

final _equipmentProvider = FutureProvider.autoDispose<List<Equipment>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return [];
  try {
    return await ref.read(apiRepositoryProvider).getEquipment(gymId, limit: 100);
  } on DioException catch (e) {
    if (e.response?.statusCode == 403 || e.response?.statusCode == 404) return [];
    rethrow;
  }
});

class EquipmentScreen extends ConsumerStatefulWidget {
  const EquipmentScreen({super.key});

  @override
  ConsumerState<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends ConsumerState<EquipmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  String _status = 'Active';
  bool _submitting = false;
  int? _editingId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  void _showForm([Equipment? equipment]) {
    if (equipment != null) {
      _editingId = equipment.id;
      _nameCtrl.text = equipment.name;
      _brandCtrl.text = equipment.brand ?? '';
      _categoryCtrl.text = equipment.category;
      _status = equipment.status;
    } else {
      _editingId = null;
      _nameCtrl.clear();
      _brandCtrl.clear();
      _categoryCtrl.clear();
      _status = 'Active';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_editingId != null ? 'Edit Equipment' : 'Add Equipment',
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _decor('Equipment Name *'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _brandCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _decor('Brand (Optional)'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _categoryCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _decor('Category * (e.g. Cardio)'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _status,
                items: const [
                  DropdownMenuItem(value: 'Active', child: Text('Active')),
                  DropdownMenuItem(value: 'Broken', child: Text('Broken')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setModalState(() => _status = v);
                  }
                },
                decoration: _decor('Status'),
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : () => _submit(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _submitting
                      ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.black)
                      : Text(_editingId != null ? 'Save Changes' : 'Add Equipment',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
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
        'brand': _brandCtrl.text.trim(),
        'category': _categoryCtrl.text.trim(),
        'status': _status,
      };
      if (_editingId != null) {
        await ref.read(apiRepositoryProvider).updateEquipment(_editingId!, gymId, data);
      } else {
        await ref.read(apiRepositoryProvider).createEquipment(gymId, data);
      }
      ref.invalidate(_equipmentProvider);
      if (ctx.mounted) Navigator.pop(ctx);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.parse(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Delete Equipment?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('This action cannot be undone.', style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(apiRepositoryProvider).deleteEquipment(id);
      ref.invalidate(_equipmentProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.parse(e))));
    }
  }

  InputDecoration _decor(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent)),
      );

  @override
  Widget build(BuildContext context) {
    final eqAsync = ref.watch(_equipmentProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Equipment', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showForm(),
              icon: const Icon(Icons.add_rounded, size: 18, color: Colors.black),
              label: const Text('Add', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: eqAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
        error: (e, _) => Center(child: Text(ErrorHandler.parse(e), style: const TextStyle(color: AppColors.error))),
        data: (list) {
          if (list.isEmpty) {
            return RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.card,
              onRefresh: () async => ref.invalidate(_equipmentProvider),
              child: ListView(children: const [
                SizedBox(height: 200),
                Center(child: Text('No equipment found. Tap Add to start.', style: TextStyle(color: AppColors.textMuted))),
              ]),
            );
          }
          return RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.card,
            onRefresh: () async => ref.invalidate(_equipmentProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final eq = list[i];
                final isBroken = eq.status == 'Broken';
                
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(eq.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text(eq.category, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 13)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isBroken ? const Color(0xFF7F1D1D).withAlpha(76) : const Color(0xFF14532D).withAlpha(76),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(isBroken ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                                    size: 14, color: isBroken ? const Color(0xFFF87171) : const Color(0xFF4ADE80)),
                                const SizedBox(width: 4),
                                Text(eq.status,
                                    style: TextStyle(
                                        color: isBroken ? const Color(0xFFF87171) : const Color(0xFF4ADE80),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (eq.brand != null && eq.brand!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Brand: ', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                            Text(eq.brand!, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                          ],
                        ),
                      ],
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(color: AppColors.border, height: 1),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _showForm(eq),
                            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted, visualDensity: VisualDensity.compact),
                            child: const Text('Edit'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => _delete(eq.id),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444), visualDensity: VisualDensity.compact),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
