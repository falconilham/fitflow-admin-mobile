import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/drawer_menu_button.dart';
import '../../../shared/utils/error_handler.dart';

// State providers for filtering
final classDayFilterProvider = StateProvider<String?>((ref) => null);
final classCategoryFilterProvider = StateProvider<int?>((ref) => null);

final classesListProvider = FutureProvider.autoDispose<List<GymClass>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return [];
  
  final day = ref.watch(classDayFilterProvider);
  final catId = ref.watch(classCategoryFilterProvider);
  
  try {
    return await ref.read(apiRepositoryProvider).getClasses(
      gymId,
      day: day,
      categoryId: catId,
    );
  } on DioException catch (e) {
    if (e.response?.statusCode == 403) {
      // Gated feature or forbidden
      throw Exception('Classes feature is not enabled for this gym or access is denied.');
    }
    rethrow;
  }
});

final classCategoriesListProvider = FutureProvider.autoDispose<List<ClassCategory>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return [];
  try {
    return await ref.read(apiRepositoryProvider).getClassCategories(gymId);
  } catch (e) {
    return [];
  }
});

class ClassesScreen extends ConsumerStatefulWidget {
  const ClassesScreen({super.key});

  @override
  ConsumerState<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends ConsumerState<ClassesScreen> {
  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesListProvider);
    final categoriesAsync = ref.watch(classCategoriesListProvider);
    
    final selectedDay = ref.watch(classDayFilterProvider);
    final selectedCat = ref.watch(classCategoryFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('GROUP CLASSES'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_rounded, color: AppColors.textSecondary),
            tooltip: 'Manage Categories',
            onPressed: () => context.push(AppRoutes.classCategories).then((_) {
              ref.invalidate(classCategoriesListProvider);
              ref.invalidate(classesListProvider);
            }),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.accent),
            tooltip: 'Add Class',
            onPressed: () => context.push(AppRoutes.addClass).then((_) {
              ref.invalidate(classesListProvider);
            }),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar - Day selector
          Container(
            height: 52,
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildDayChip('All Days', null, selectedDay == null),
                ..._days.map((day) => _buildDayChip(day, day, selectedDay == day)),
              ],
            ),
          ),

          // Filter Bar - Category selector
          categoriesAsync.when(
            data: (categories) {
              if (categories.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list_rounded, size: 18, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildCatChip('All Categories', null, selectedCat == null),
                            ...categories.map((cat) => _buildCatChip(cat.name, cat.id, selectedCat == cat.id)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Divider
          const Divider(height: 1, color: AppColors.border),

          // Classes List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(classesListProvider);
                ref.invalidate(classCategoriesListProvider);
              },
              color: AppColors.accent,
              backgroundColor: AppColors.card,
              child: classesAsync.when(
                data: (classes) {
                  if (classes.isEmpty) {
                    return _buildEmptyState();
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: classes.length,
                    itemBuilder: (ctx, index) {
                      return _buildClassCard(classes[index]);
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.gpp_bad_rounded, size: 48, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text(
                          error.toString().contains('Classes feature')
                              ? 'Group Classes feature is disabled for this Gym plan.\nEnable it in Gym Settings or upgrade plan.'
                              : ErrorHandler.parse(error),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayChip(String label, String? value, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        selected: isSelected,
        selectedColor: AppColors.accent,
        backgroundColor: AppColors.card,
        elevation: 0,
        pressElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected ? Colors.transparent : AppColors.border,
          ),
        ),
        onSelected: (selected) {
          if (selected) {
            ref.read(classDayFilterProvider.notifier).state = value;
          }
        },
      ),
    );
  }

  Widget _buildCatChip(String label, int? value, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          ref.read(classCategoryFilterProvider.notifier).state = value;
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent.withAlpha(30) : AppColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassCard(GymClass gymClass) {
    // Parse color if present, fallback to accent
    Color classColor = AppColors.accent;
    if (gymClass.color != null && gymClass.color!.startsWith('#')) {
      try {
        final hex = gymClass.color!.replaceAll('#', '');
        classColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    } else if (gymClass.categoryColor != null && gymClass.categoryColor!.startsWith('#')) {
      try {
        final hex = gymClass.categoryColor!.replaceAll('#', '');
        classColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    final isFull = gymClass.booked >= gymClass.capacity;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: gymClass.isActive ? AppColors.border : AppColors.border.withAlpha(80)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/classes/${gymClass.id}/roster').then((_) {
          ref.invalidate(classesListProvider);
        }),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colored status accent line
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: gymClass.isActive ? classColor : Colors.grey[700],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row with Category Tag and Day/Time
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Category Tag
                      if (gymClass.categoryName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: classColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: classColor.withAlpha(80), width: 0.5),
                          ),
                          child: Text(
                            gymClass.categoryName!.toUpperCase(),
                            style: TextStyle(
                              color: classColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border, width: 0.5),
                          ),
                          child: const Text(
                            'UNGROUPED',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      // Day of Week + Time
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${gymClass.day}, ${gymClass.time}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    gymClass.title,
                    style: TextStyle(
                      color: gymClass.isActive ? AppColors.textPrimary : AppColors.textSecondary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      decoration: gymClass.isActive ? null : TextDecoration.lineThrough,
                    ),
                  ),

                  // Description if present
                  if (gymClass.description != null && gymClass.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      gymClass.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 12),

                  // Footer info: Trainer, Duration, Booked quota
                  Row(
                    children: [
                      // Trainer & Duration
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_rounded, size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    gymClass.trainer.isNotEmpty ? gymClass.trainer : 'No trainer assigned',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.timer_rounded, size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 6),
                                Text(
                                  '${gymClass.duration} mins duration',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Capacity Meter Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isFull
                              ? AppColors.warning.withAlpha(20)
                              : AppColors.accent.withAlpha(15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isFull ? AppColors.warning : AppColors.accent.withAlpha(50),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFull ? Icons.warning_rounded : Icons.people_outline_rounded,
                              size: 14,
                              color: isFull ? AppColors.warning : AppColors.accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${gymClass.booked} / ${gymClass.capacity}',
                              style: TextStyle(
                                color: isFull ? AppColors.warning : AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Edit button
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.textMuted),
                        onPressed: () => context.push('/classes/${gymClass.id}/edit').then((_) {
                          ref.invalidate(classesListProvider);
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.groups_rounded, size: 48, color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Classes Scheduled',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Schedule group fitness sessions like Yoga, HIIT, or Zumba, set capacities, and manage waitlists easily.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push(AppRoutes.addClass).then((_) {
                ref.invalidate(classesListProvider);
              }),
              icon: const Icon(Icons.add_rounded, color: Colors.black),
              label: const Text('Schedule First Class', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }
}
