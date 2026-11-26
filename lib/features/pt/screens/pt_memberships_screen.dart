import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/utils/error_handler.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/drawer_menu_button.dart';

final _ptMembershipsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return [];
  return ref.read(apiRepositoryProvider).getTrainerPackages(gymId);
});

final _ptAssignMembersProvider =
    FutureProvider.autoDispose<List<Member>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return [];
  return ref.read(apiRepositoryProvider).getMembers(gymId, limit: 100);
});

final _ptAssignTrainersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return [];
  return ref.read(apiRepositoryProvider).getTrainers(gymId);
});

class PtMembershipsScreen extends ConsumerStatefulWidget {
  const PtMembershipsScreen({super.key});

  @override
  ConsumerState<PtMembershipsScreen> createState() =>
      _PtMembershipsScreenState();
}

class _PtMembershipsScreenState extends ConsumerState<PtMembershipsScreen> {
  String _statusFilter = 'all';

  Future<void> _openCreateModal() async {
    final members = await ref.read(_ptAssignMembersProvider.future);
    final trainers = await ref.read(_ptAssignTrainersProvider.future);
    if (!mounted) return;

    int? selectedMemberId = members.isNotEmpty ? members.first.id : null;
    int? selectedTrainerId =
        trainers.isNotEmpty ? (trainers.first['id'] as num?)?.toInt() : null;
    final sessionsCtrl = TextEditingController(text: '10');
    final priceCtrl = TextEditingController(text: '1500000');
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tambah Membership PT',
                  style: GoogleFonts.figtree(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: selectedMemberId,
                  dropdownColor: AppColors.card,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Member'),
                  items: members
                      .map(
                        (m) => DropdownMenuItem(
                          value: m.id,
                          child: Text(m.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setModalState(() => selectedMemberId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: selectedTrainerId,
                  dropdownColor: AppColors.card,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Personal Trainer'),
                  items: trainers
                      .map(
                        (t) => DropdownMenuItem(
                          value: (t['id'] as num?)?.toInt(),
                          child: Text(
                            (t['name'] ?? '-').toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setModalState(() => selectedTrainerId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: sessionsCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(labelText: 'Sesi PT'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(labelText: 'Total Harga (Rp)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving ||
                            selectedMemberId == null ||
                            selectedTrainerId == null
                        ? null
                        : () async {
                            final gymId =
                                ref.read(authProvider).valueOrNull?.activeGymId;
                            if (gymId == null) return;
                            setModalState(() => saving = true);
                            try {
                              await ref
                                  .read(apiRepositoryProvider)
                                  .createTrainerPackage(gymId, {
                                'memberId': selectedMemberId,
                                'trainerId': selectedTrainerId,
                                'totalSessions':
                                    int.tryParse(sessionsCtrl.text) ?? 10,
                                'packagePrice':
                                    int.tryParse(priceCtrl.text) ?? 0,
                              });
                              ref.invalidate(_ptMembershipsProvider);
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ErrorHandler.parse(e)),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            } finally {
                              if (modalCtx.mounted) {
                                setModalState(() => saving = false);
                              }
                            }
                          },
                    child: Text(saving ? 'Menyimpan...' : 'Simpan Membership PT'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final listAsync = ref.watch(_ptMembershipsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: Text(l10n.ptMembershipsTitle),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus, color: AppColors.accent),
            onPressed: _openCreateModal,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              children: [
                for (final entry in const [
                  ('all', 'Semua'),
                  ('active', 'Aktif'),
                  ('completed', 'Selesai'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.$2),
                      selected: _statusFilter == entry.$1,
                      selectedColor: AppColors.accent,
                      backgroundColor: AppColors.card,
                      labelStyle: GoogleFonts.figtree(
                        color: _statusFilter == entry.$1
                            ? AppColors.background
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      side: const BorderSide(color: AppColors.border),
                      onSelected: (_) =>
                          setState(() => _statusFilter = entry.$1),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.card,
              onRefresh: () async => ref.invalidate(_ptMembershipsProvider),
              child: listAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                error: (e, _) => Center(
                  child: Text(
                    ErrorHandler.parse(e),
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
                data: (items) {
                  final filtered = _statusFilter == 'all'
                      ? items
                      : items
                          .where(
                            (e) =>
                                (e['status'] ?? '').toString().toLowerCase() ==
                                _statusFilter,
                          )
                          .toList();

                  if (filtered.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(
                            l10n.ptMembershipsEmpty,
                            style: GoogleFonts.figtree(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final pkg = filtered[i];
                      final memberName =
                          ((pkg['member'] as Map?)?['name'] ?? 'Member')
                              .toString();
                      final trainerName =
                          ((pkg['trainer'] as Map?)?['name'] ?? 'Trainer')
                              .toString();
                      final total =
                          (pkg['totalSessions'] as num?)?.toInt() ?? 0;
                      final remaining =
                          (pkg['remainingSessions'] as num?)?.toInt() ?? 0;
                      final price =
                          (pkg['packagePrice'] as num?)?.toDouble() ?? 0;
                      final status =
                          (pkg['status'] ?? 'active').toString().toLowerCase();
                      final isActive = status == 'active';

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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    memberName,
                                    style: GoogleFonts.figtree(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? AppColors.successPillBg
                                        : AppColors.infoPillBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: GoogleFonts.figtree(
                                      color: isActive
                                          ? AppColors.successPillText
                                          : AppColors.infoPillText,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Trainer: $trainerName',
                              style: GoogleFonts.figtree(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Sisa Sesi PT: $remaining / $total',
                                  style: GoogleFonts.figtree(
                                    color: AppColors.accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  formatCurrency(price),
                                  style: GoogleFonts.figtree(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
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
