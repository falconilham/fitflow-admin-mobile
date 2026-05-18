import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/classes/screens/classes_screen.dart';
import '../../../shared/utils/error_handler.dart';

class ClassCategoriesScreen extends ConsumerStatefulWidget {
  const ClassCategoriesScreen({super.key});

  @override
  ConsumerState<ClassCategoriesScreen> createState() => _ClassCategoriesScreenState();
}

class _ClassCategoriesScreenState extends ConsumerState<ClassCategoriesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  
  // Preset dark mode friendly palette colors
  final List<String> _colors = [
    '#CCFF00', // Electric Lime
    '#3B82F6', // Neon Blue
    '#EF4444', // Red
    '#10B981', // Emerald
    '#F59E0B', // Amber
    '#EC4899', // Hot Pink
    '#8B5CF6', // Purple
    '#06B6D4', // Cyan
  ];
  
  String _selectedColor = '#CCFF00';
  int? _editingId;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _nameCtrl.clear();
      _selectedColor = '#CCFF00';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    
    setState(() => _submitting = true);
    
    try {
      final data = {
        'name': _nameCtrl.text.trim(),
        'color': _selectedColor,
      };
      
      final repo = ref.read(apiRepositoryProvider);
      if (_editingId != null) {
        await repo.updateClassCategory(_editingId!, data);
      } else {
        await repo.createClassCategory(gymId, data);
      }
      
      _resetForm();
      ref.invalidate(classCategoriesListProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Category saved successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.parse(e)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Category?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Any scheduled class using this category will lose its category assignment, but the class itself will NOT be deleted.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(apiRepositoryProvider).deleteClassCategory(id);
      ref.invalidate(classCategoriesListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Category deleted!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.parse(e)), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(classCategoriesListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('CLASS CATEGORIES'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Inline Form
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _editingId != null ? 'Edit Category' : 'Create Category',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nameCtrl,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'e.g. Yoga, Zumba, HIIT',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Cancel edit button
                      if (_editingId != null)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                          onPressed: _resetForm,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Color selection label
                  const Text(
                    'Tag Accent Color',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Horizontal Color List
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _colors.length,
                      itemBuilder: (ctx, index) {
                        final colorHex = _colors[index];
                        final color = Color(int.parse('FF${colorHex.replaceAll('#', '')}', radix: 16));
                        final isSelected = _selectedColor == colorHex;
                        
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = colorHex),
                          child: Container(
                            width: 32,
                            height: 32,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: color.withAlpha(120), blurRadius: 8, spreadRadius: 1)]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check_rounded, color: Colors.black, size: 16)
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                            )
                          : Text(
                              _editingId != null ? 'Update Category' : 'Save Category',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Categories List Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Text(
                  'ALL CATEGORIES',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          
          // Categories list view
          Expanded(
            child: categoriesAsync.when(
              data: (categories) {
                if (categories.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.category_outlined, size: 40, color: AppColors.textMuted.withAlpha(100)),
                        const SizedBox(height: 8),
                        const Text('No categories created yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  itemBuilder: (ctx, index) {
                    final cat = categories[index];
                    Color catColor = AppColors.accent;
                    if (cat.color != null && cat.color!.startsWith('#')) {
                      try {
                        catColor = Color(int.parse('FF${cat.color!.replaceAll('#', '')}', radix: 16));
                      } catch (_) {}
                    }
                    
                    return Card(
                      color: AppColors.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(color: catColor, shape: BoxShape.circle),
                        ),
                        title: Text(
                          cat.name,
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.textSecondary),
                              onPressed: () {
                                setState(() {
                                  _editingId = cat.id;
                                  _nameCtrl.text = cat.name;
                                  if (cat.color != null) {
                                    _selectedColor = cat.color!;
                                  }
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                              onPressed: () => _delete(cat.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
              error: (err, _) => Center(child: Text(ErrorHandler.parse(err), style: const TextStyle(color: AppColors.error))),
            ),
          ),
        ],
      ),
    );
  }
}
