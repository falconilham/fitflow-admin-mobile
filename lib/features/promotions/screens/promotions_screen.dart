import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/utils/error_handler.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/drawer_menu_button.dart';

class PromotionsScreen extends ConsumerStatefulWidget {
  const PromotionsScreen({super.key});

  @override
  ConsumerState<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends ConsumerState<PromotionsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _promos = const [];

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
      final rows = await ref.read(apiRepositoryProvider).getPromotions(gymId);
      if (!mounted) return;
      setState(() {
        _promos = rows;
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

  Future<void> _openEditor([Map<String, dynamic>? existing]) async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;

    final codeCtrl = TextEditingController(text: existing?['code'] as String? ?? '');
    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final valueCtrl = TextEditingController(
      text: ((existing?['discountValue'] as num?)?.toInt() ?? 10).toString(),
    );
    final limitCtrl = TextEditingController(
      text: (existing?['usageLimit'] as num?)?.toInt().toString() ?? '',
    );
    var discountType = existing?['discountType'] as String? ?? 'PERCENTAGE';
    var isActive = existing?['isActive'] as bool? ?? true;
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing == null ? 'Buat Kode Promo Baru' : 'Edit Kode Promo',
                style: GoogleFonts.figtree(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Kode Promo * (misal HEMAT20)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Promo *'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: discountType,
                      dropdownColor: AppColors.card,
                      decoration: const InputDecoration(labelText: 'Tipe Diskon'),
                      items: const [
                        DropdownMenuItem(
                          value: 'PERCENTAGE',
                          child: Text('Persentase (%)'),
                        ),
                        DropdownMenuItem(
                          value: 'FIXED_AMOUNT',
                          child: Text('Nominal (Rp)'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setModalState(() => discountType = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: valueCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: discountType == 'PERCENTAGE'
                            ? 'Diskon (%)'
                            : 'Diskon (Rp)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: limitCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Batas Pemakaian (kosongkan jika tanpa batas)',
                ),
              ),
              SwitchListTile(
                value: isActive,
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.accent,
                title: const Text('Promo Aktif'),
                onChanged: (v) => setModalState(() => isActive = v),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (codeCtrl.text.trim().isEmpty ||
                              nameCtrl.text.trim().isEmpty) {
                            return;
                          }
                          final messenger = ScaffoldMessenger.of(ctx);
                          setModalState(() => saving = true);
                          try {
                            final repo = ref.read(apiRepositoryProvider);
                            final limitVal = int.tryParse(limitCtrl.text.trim());
                            final payload = {
                              'code': codeCtrl.text.trim().toUpperCase(),
                              'name': nameCtrl.text.trim(),
                              'discountType': discountType,
                              'discountValue':
                                  int.tryParse(valueCtrl.text.trim()) ?? 0,
                              'usageLimit': limitVal,
                              'isActive': isActive,
                            };
                            if (existing == null) {
                              await repo.createPromotion(gymId, payload);
                            } else {
                              await repo.updatePromotion(
                                (existing['id'] as num).toInt(),
                                gymId,
                                payload,
                              );
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
                  child: Text(saving ? 'Menyimpan...' : 'Simpan Promo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    codeCtrl.dispose();
    nameCtrl.dispose();
    valueCtrl.dispose();
    limitCtrl.dispose();
    if (saved == true) await _load();
  }

  Future<void> _toggleActive(Map<String, dynamic> promo, bool nextVal) async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    try {
      await ref.read(apiRepositoryProvider).updatePromotion(
        (promo['id'] as num).toInt(),
        gymId,
        {'isActive': nextVal},
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.parse(e)), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _deletePromo(int id) async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    try {
      await ref.read(apiRepositoryProvider).deletePromotion(id, gymId);
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: Text(l10n.menuPromotions),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus, color: AppColors.accent),
            onPressed: () => _openEditor(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.card,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
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
                : _promos.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(
                            child: Text(
                              'Belum ada kode promo & voucher',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _promos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, idx) {
                          final p = _promos[idx];
                          final code = p['code'] as String? ?? '-';
                          final name = p['name'] as String? ?? '-';
                          final type = p['discountType'] as String? ?? 'PERCENTAGE';
                          final val = (p['discountValue'] as num?)?.toDouble() ?? 0;
                          final used = (p['usedCount'] as num?)?.toInt() ?? 0;
                          final limit = (p['usageLimit'] as num?)?.toInt();
                          final bonusPt = (p['bonusPtSessions'] as num?)?.toInt() ?? 0;
                          final active = p['isActive'] as bool? ?? false;

                          final discountText = type == 'PERCENTAGE'
                              ? 'Diskon ${val.toInt()}%'
                              : 'Diskon ${formatCurrency(val)}';

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentPill,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.accent,
                                        ),
                                      ),
                                      child: Text(
                                        code,
                                        style: GoogleFonts.figtree(
                                          color: AppColors.accent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Switch(
                                      value: active,
                                      activeThumbColor: AppColors.accent,
                                      onChanged: (v) => _toggleActive(p, v),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  name,
                                  style: GoogleFonts.figtree(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$discountText • Terpakai $used${limit != null ? '/$limit' : ''}'
                                  '${bonusPt > 0 ? ' • +$bonusPt PT SESSIONS' : ''}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _openEditor(p),
                                      icon: const Icon(LucideIcons.pencil, size: 14),
                                      label: const Text('Edit'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _deletePromo(
                                        (p['id'] as num).toInt(),
                                      ),
                                      icon: const Icon(
                                        LucideIcons.trash2,
                                        size: 14,
                                        color: AppColors.error,
                                      ),
                                      label: const Text(
                                        'Hapus',
                                        style: TextStyle(color: AppColors.error),
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
    );
  }
}
