import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/utils/error_handler.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/drawer_menu_button.dart';
import '../../../shared/widgets/feature_guide_banner.dart';

final _ptPackagesProvider =
    FutureProvider.autoDispose<List<MembershipPackage>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return [];
  return ref.read(apiRepositoryProvider).getPackages(gymId, type: 'PT');
});

class PtPackagesScreen extends ConsumerStatefulWidget {
  const PtPackagesScreen({super.key});

  @override
  ConsumerState<PtPackagesScreen> createState() => _PtPackagesScreenState();
}

class _PtPackagesScreenState extends ConsumerState<PtPackagesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _sessionsCtrl = TextEditingController(text: '10');
  final _durationMonthsCtrl = TextEditingController(text: '3');
  final _descCtrl = TextEditingController();
  bool _saving = false;
  int? _editingId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _sessionsCtrl.dispose();
    _durationMonthsCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _openEditor([MembershipPackage? pkg]) {
    if (pkg != null) {
      _editingId = pkg.id;
      _nameCtrl.text = pkg.name;
      _priceCtrl.text = pkg.price.toString();
      _sessionsCtrl.text = (pkg.totalSessions ?? pkg.bonusPtSessions).toString();
      _durationMonthsCtrl.text = pkg.durationMonths.toString();
      _descCtrl.text = pkg.description ?? '';
    } else {
      _editingId = null;
      _nameCtrl.clear();
      _priceCtrl.clear();
      _sessionsCtrl.text = '10';
      _durationMonthsCtrl.text = '3';
      _descCtrl.clear();
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _editingId == null ? 'Tambah Paket PT' : 'Edit Paket PT',
                  style: GoogleFonts.figtree(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Nama Paket PT'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _sessionsCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(labelText: 'Jumlah Sesi PT'),
                        validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0
                            ? 'Harus > 0'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _durationMonthsCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(labelText: 'Masa Berlaku (Bln)'),
                        validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0
                            ? 'Harus > 0'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Harga Paket (Rp)'),
                  validator: (v) => (int.tryParse(v ?? '') ?? -1) < 0
                      ? 'Harga tidak valid'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Catatan / Deskripsi'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : () => _save(ctx),
                    child: Text(_saving ? 'Menyimpan...' : 'Simpan Paket PT'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save(BuildContext sheetCtx) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;

    setState(() => _saving = true);
    final sessions = int.parse(_sessionsCtrl.text.trim());
    final payload = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'type': 'PT',
      'price': int.parse(_priceCtrl.text.trim()),
      'durationMonths': int.parse(_durationMonthsCtrl.text.trim()),
      'totalSessions': sessions,
      'bonusPtSessions': sessions,
      'description': _descCtrl.text.trim(),
      'isActive': true,
    };

    try {
      final repo = ref.read(apiRepositoryProvider);
      if (_editingId == null) {
        await repo.createPackage(gymId, payload);
      } else {
        await repo.updatePackage(_editingId!, payload);
      }
      ref.invalidate(_ptPackagesProvider);
      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
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
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deletePackage(int id) async {
    try {
      await ref.read(apiRepositoryProvider).deletePackage(id);
      ref.invalidate(_ptPackagesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.parse(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final packagesAsync = ref.watch(_ptPackagesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: Text(l10n.ptPackagesTitle),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.creditCard, color: AppColors.textPrimary),
            tooltip: l10n.menuPtMemberships,
            onPressed: () => context.push(AppRoutes.ptMemberships),
          ),
          IconButton(
            icon: const Icon(LucideIcons.plus, color: AppColors.accent),
            onPressed: () => _openEditor(),
          ),
        ],
      ),
      body: Column(
        children: [
          FeatureGuideBanner(
            title: l10n.ptGuideTitle,
            summary: l10n.ptGuideSummary,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            items: [
              FeatureGuideItem(
                icon: LucideIcons.dumbbell,
                text: l10n.ptGuideSoloGroup,
              ),
              FeatureGuideItem(
                icon: LucideIcons.shieldCheck,
                text: l10n.ptGuideDeduction,
              ),
              FeatureGuideItem(
                icon: LucideIcons.wallet,
                text: l10n.ptGuideCommission,
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.card,
              onRefresh: () async => ref.invalidate(_ptPackagesProvider),
              child: packagesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      ErrorHandler.parse(e),
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ),
                data: (packages) {
                  if (packages.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 100),
                        Center(
                          child: Column(
                            children: [
                              const Icon(
                                LucideIcons.shoppingBag,
                                size: 40,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                l10n.ptPackagesEmpty,
                                style: GoogleFonts.figtree(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: packages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final pkg = packages[i];
                      final sessions = pkg.totalSessions ?? pkg.bonusPtSessions;
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.iconSurface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                LucideIcons.dumbbell,
                                size: 20,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pkg.name,
                                    style: GoogleFonts.figtree(
                                      color: AppColors.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$sessions PT SESSIONS · ${pkg.durationMonths} Bulan · ${formatCurrency(pkg.price.toDouble())}',
                                    style: GoogleFonts.figtree(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                LucideIcons.pencil,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () => _openEditor(pkg),
                            ),
                            IconButton(
                              icon: const Icon(
                                LucideIcons.trash2,
                                size: 18,
                                color: AppColors.error,
                              ),
                              onPressed: () => _deletePackage(pkg.id),
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
