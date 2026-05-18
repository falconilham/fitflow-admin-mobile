import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/classes/screens/classes_screen.dart';
import '../../../shared/utils/error_handler.dart';

// Fetch all trainers to display in dropdown
final trainersListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return [];
  try {
    return await ref.read(apiRepositoryProvider).getTrainers(gymId);
  } catch (e) {
    return [];
  }
});

final classDetailsProvider = FutureProvider.family.autoDispose<GymClass, int>((ref, classId) async {
  final data = await ref.read(apiRepositoryProvider).getClassBookings(classId);
  return data['class'] as GymClass;
});

class AddEditClassScreen extends ConsumerStatefulWidget {
  final int? classId;
  const AddEditClassScreen({super.key, this.classId});

  @override
  ConsumerState<AddEditClassScreen> createState() => _AddEditClassScreenState();
}

class _AddEditClassScreenState extends ConsumerState<AddEditClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '60');
  final _capacityCtrl = TextEditingController(text: '15');
  
  String _selectedDay = 'Monday';
  String _selectedTime = '08:00';
  int? _selectedTrainerId;
  int? _selectedCategoryId;
  String _selectedColor = '#CCFF00';
  bool _isActive = true;
  
  bool _loadingDetails = false;
  bool _submitting = false;

  final List<String> _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  final List<String> _presetColors = [
    '#CCFF00', '#3B82F6', '#EF4444', '#10B981', '#F59E0B', '#EC4899', '#8B5CF6', '#06B6D4'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.classId != null) {
      _loadClassDetails();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _durationCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClassDetails() async {
    setState(() => _loadingDetails = true);
    try {
      final gymClass = await ref.read(classDetailsProvider(widget.classId!).future);
      _titleCtrl.text = gymClass.title;
      _descCtrl.text = gymClass.description ?? '';
      _durationCtrl.text = gymClass.duration;
      _capacityCtrl.text = gymClass.capacity.toString();
      setState(() {
        _selectedDay = gymClass.day;
        _selectedTime = gymClass.time;
        _selectedTrainerId = gymClass.trainerId;
        _selectedCategoryId = gymClass.categoryId;
        _isActive = gymClass.isActive;
        if (gymClass.color != null) {
          _selectedColor = gymClass.color!;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load class: ${ErrorHandler.parse(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  Future<void> _selectTime() async {
    final parts = _selectedTime.split(':');
    final initialHour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 8 : 8;
    final initialMinute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accent,
              surface: AppColors.card,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final hour = picked.hour.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      setState(() {
        _selectedTime = '$hour:$minute';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    
    setState(() => _submitting = true);
    
    try {
      final data = {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'trainerId': _selectedTrainerId,
        'categoryId': _selectedCategoryId,
        'day': _selectedDay,
        'time': _selectedTime,
        'duration': _durationCtrl.text.trim(),
        'capacity': int.tryParse(_capacityCtrl.text) ?? 15,
        'color': _selectedColor,
        'isActive': _isActive,
      };
      
      final repo = ref.read(apiRepositoryProvider);
      
      if (widget.classId != null) {
        await repo.updateClass(widget.classId!, data);
      } else {
        await repo.createClass(gymId, data);
      }
      
      ref.invalidate(classesListProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.classId != null ? 'Class updated!' : 'Class scheduled!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
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

  Future<void> _deleteClass() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Scheduled Class?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This action is permanent. You can only delete classes that have zero active bookings.',
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
      await ref.read(apiRepositoryProvider).deleteClass(widget.classId!);
      ref.invalidate(classesListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class deleted successfully!'), behavior: SnackBarBehavior.floating),
        );
        context.pop();
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
    final trainersAsync = ref.watch(trainersListProvider);
    final categoriesAsync = ref.watch(classCategoriesListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.classId != null ? 'EDIT CLASS' : 'SCHEDULE CLASS'),
        centerTitle: true,
        actions: [
          if (widget.classId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              tooltip: 'Delete Class',
              onPressed: _deleteClass,
            ),
        ],
      ),
      body: _loadingDetails
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Class Title
                    const Text('Class Title *', style: _labelStyle),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleCtrl,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: _inputDecor('e.g. Morning Vinyasa Yoga'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 18),

                    // Description
                    const Text('Description', style: _labelStyle),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: _inputDecor('Explain benefits, skill level required, etc.'),
                    ),
                    const SizedBox(height: 18),

                    // Day & Start Time Row
                    Row(
                      children: [
                        // Day Selection
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Day of Week *', style: _labelStyle),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedDay,
                                dropdownColor: AppColors.card,
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                                decoration: _inputDecor(''),
                                items: _days.map((day) {
                                  return DropdownMenuItem(value: day, child: Text(day));
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _selectedDay = v);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Start Time Selector
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Start Time *', style: _labelStyle),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: _selectTime,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                                  decoration: BoxDecoration(
                                    color: AppColors.card,
                                    border: Border.all(color: AppColors.border),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _selectedTime,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Icon(Icons.access_time_rounded, size: 18, color: AppColors.accent),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Duration & Capacity Row
                    Row(
                      children: [
                        // Duration
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Duration (mins) *', style: _labelStyle),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _durationCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                                decoration: _inputDecor('Minutes'),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Capacity
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Max Capacity *', style: _labelStyle),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _capacityCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                                decoration: _inputDecor('Max spots'),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Trainer dropdown
                    const Text('Trainer / Instructor *', style: _labelStyle),
                    const SizedBox(height: 8),
                    trainersAsync.when(
                      data: (trainers) {
                        return DropdownButtonFormField<int>(
                          initialValue: _selectedTrainerId,
                          dropdownColor: AppColors.card,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          decoration: _inputDecor('Select Trainer'),
                          items: trainers.map((t) {
                            return DropdownMenuItem<int>(
                              value: t['id'] as int,
                              child: Text(t['name'].toString()),
                            );
                          }).toList(),
                          validator: (v) => v == null ? 'Trainer is required' : null,
                          onChanged: (v) => setState(() => _selectedTrainerId = v),
                        );
                      },
                      loading: () => const LinearProgressIndicator(color: AppColors.accent),
                      error: (err, _) => Text('Error loading trainers: ${err.toString()}', style: const TextStyle(color: AppColors.error)),
                    ),
                    const SizedBox(height: 18),

                    // Category dropdown
                    const Text('Category', style: _labelStyle),
                    const SizedBox(height: 8),
                    categoriesAsync.when(
                      data: (categories) {
                        return DropdownButtonFormField<int>(
                          initialValue: _selectedCategoryId,
                          dropdownColor: AppColors.card,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          decoration: _inputDecor('Ungrouped / Optional'),
                          items: [
                            const DropdownMenuItem<int>(value: null, child: Text('Ungrouped (None)')),
                            ...categories.map((c) {
                              return DropdownMenuItem<int>(
                                value: c.id,
                                child: Text(c.name),
                              );
                            })
                          ],
                          onChanged: (v) => setState(() => _selectedCategoryId = v),
                        );
                      },
                      loading: () => const LinearProgressIndicator(color: AppColors.accent),
                      error: (err, _) => Text('Error: ${err.toString()}', style: const TextStyle(color: AppColors.error)),
                    ),
                    const SizedBox(height: 18),

                    // Color Picker
                    const Text('Class Tag Color Accent', style: _labelStyle),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 38,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _presetColors.length,
                        itemBuilder: (ctx, index) {
                          final colorHex = _presetColors[index];
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
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check_rounded, color: Colors.black, size: 16)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Active Switch
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: SwitchListTile(
                        value: _isActive,
                        activeThumbColor: AppColors.accent,
                        title: const Text(
                          'Show Class to Members',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: const Text(
                          'Inactive classes are hidden from member-side self bookings.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                              )
                            : Text(
                                widget.classId != null ? 'SAVE CHANGES' : 'CREATE SCHEDULE',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

const TextStyle _labelStyle = TextStyle(
  color: AppColors.textSecondary,
  fontSize: 12,
  fontWeight: FontWeight.bold,
);

InputDecoration _inputDecor(String hint) {
  return InputDecoration(
    hintText: hint,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    fillColor: AppColors.card,
  );
}
