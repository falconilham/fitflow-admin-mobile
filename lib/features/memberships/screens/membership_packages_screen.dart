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

class MembershipPackagesScreen extends ConsumerStatefulWidget {
  const MembershipPackagesScreen({super.key});

  @override
  ConsumerState<MembershipPackagesScreen> createState() =>
      _MembershipPackagesScreenState();
}

class _MembershipPackagesScreenState
    extends ConsumerState<MembershipPackagesScreen> {
  String _typeFilter = 'ALL';
  bool _loading = true;
  String? _error;
  List<MembershipPackage> _packages = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(apiRepositoryProvider).getPackages(gymId);
      final filtered = list.where((p) => p.type != 'PT').toList();
      if (!mounted) return;
      setState(() {
        _packages = filtered;
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

  Future<void> _openEditor([MembershipPackage? existing]) async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl =
        TextEditingController(text: existing != null ? '${existing.price}' : '');
    final durationCtrl = TextEditingController(
      text: '${existing?.durationMonths ?? 1}',
    );
    final sessionsCtrl = TextEditingController(
      text: '${existing?.totalSessions ?? 10}',
    );
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    var pkgType = existing?.type ?? 'PERIOD';
    if (pkgType != 'SESSION' && pkgType != 'PERIOD') pkgType = 'PERIOD';
    var saving = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing == null
                      ? 'Tambah Paket Membership'
                      : 'Edit Paket Membership',
                  style: GoogleFonts.figtree(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Paket *'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: pkgType,
                  dropdownColor: AppColors.card,
                  decoration: const InputDecoration(labelText: 'Tipe Paket'),
                  items: const [
                    DropdownMenuItem(
                      value: 'PERIOD',
                      child: Text('Durasi Waktu (Bulanan/Tahunan)'),
                    ),
                    DropdownMenuItem(
                      value: 'SESSION',
                      child: Text('GYM SESSIONS (Kunjungan Gym)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => pkgType = v);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Harga (Rp) *'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: pkgType == 'SESSION'
                          ? TextField(
                              controller: sessionsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Kuota GYM SESSIONS',
                              ),
                            )
                          : TextField(
                              controller: durationCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Durasi (Bulan)',
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Deskripsi'),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (nameCtrl.text.trim().isEmpty ||
                                (int.tryParse(priceCtrl.text.trim()) ?? -1) <
                                    0) {
                              return;
                            }
                            final messenger = ScaffoldMessenger.of(ctx);
                            setModalState(() => saving = true);
                            try {
                              final repo = ref.read(apiRepositoryProvider);
                              final payload = <String, dynamic>{
                                'name': nameCtrl.text.trim(),
                                'type': pkgType,
                                'price':
                                    int.tryParse(priceCtrl.text.trim()) ?? 0,
                                'durationMonths':
                                    int.tryParse(durationCtrl.text.trim()) ?? 1,
                                if (pkgType == 'SESSION')
                                  'totalSessions':
                                      int.tryParse(sessionsCtrl.text.trim()) ??
                                          10,
                                'description': descCtrl.text.trim(),
                              };
                              if (existing == null) {
                                await repo.createPackage(gymId, payload);
                              } else {
                                await repo.updatePackage(existing.id, payload);
                              }
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (e) {
                              setModalState(() => saving = false);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(ErrorHandler.parse(e)),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          },
                    child: Text(saving ? 'Menyimpan...' : 'Simpan Paket'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    nameCtrl.dispose();
    priceCtrl.dispose();
    durationCtrl.dispose();
    sessionsCtrl.dispose();
    descCtrl.dispose();

    if (saved == true) await _load();
  }

  Future<void> _deletePackage(int id) async {
    try {
      await ref.read(apiRepositoryProvider).deletePackage(id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.parse(e)), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visible = _typeFilter == 'ALL'
        ? _packages
        : _packages.where((p) => (p.type ?? 'PERIOD') == _typeFilter).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: Text(l10n.menuMembershipPackages),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus, color: AppColors.accent),
            onPressed: () => _openEditor(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                for (final item in const [
                  ('ALL', 'Semua'),
                  ('PERIOD', 'Durasi'),
                  ('SESSION', 'Kunjungan Gym'),
                ]) ...[
                  ChoiceChip(
                    label: Text(item.$2),
                    selected: _typeFilter == item.$1,
                    selectedColor: AppColors.accentPill,
                    backgroundColor: AppColors.card,
                    labelStyle: TextStyle(
                      color: _typeFilter == item.$1
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: _typeFilter == item.$1
                          ? AppColors.accent
                          : AppColors.border,
                    ),
                    onSelected: (_) => setState(() => _typeFilter = item.$1),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
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
                      : visible.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 120),
                                Center(
                                  child: Text(
                                    'Belum ada paket membership',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: visible.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, idx) {
                                final p = visible[idx];
                                final isSession = p.type == 'SESSION';
                                final quotaLabel = isSession
                                    ? '${p.totalSessions ?? 0} GYM SESSIONS'
                                    : '${p.durationMonths} bulan';
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
                                              p.name,
                                              style: GoogleFonts.figtree(
                                                color: AppColors.textPrimary,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSession
                                                  ? AppColors.infoPillBg
                                                  : AppColors.accentPill,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              quotaLabel,
                                              style: TextStyle(
                                                color: isSession
                                                    ? AppColors.infoPillText
                                                    : AppColors.accent,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        formatCurrency(p.price.toDouble()),
                                        style: GoogleFonts.figtree(
                                          color: AppColors.accent,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if (p.bonusPtSessions > 0) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Bonus: ${p.bonusPtSessions} PT SESSIONS',
                                          style: const TextStyle(
                                            color: AppColors.secondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                      if ((p.description ?? '').isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          p.description!,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () => _openEditor(p),
                                            icon: const Icon(
                                              LucideIcons.pencil,
                                              size: 14,
                                            ),
                                            label: const Text('Edit'),
                                          ),
                                          TextButton.icon(
                                            onPressed: () => _deletePackage(p.id),
                                            icon: const Icon(
                                              LucideIcons.trash2,
                                              size: 14,
                                              color: AppColors.error,
                                            ),
                                            label: const Text(
                                              'Hapus',
                                              style: TextStyle(
                                                color: AppColors.error,
                                              ),
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
