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

class AddonServicesScreen extends ConsumerStatefulWidget {
  const AddonServicesScreen({super.key});

  @override
  ConsumerState<AddonServicesScreen> createState() =>
      _AddonServicesScreenState();
}

class _AddonServicesScreenState extends ConsumerState<AddonServicesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _services = const [];
  List<Map<String, dynamic>> _usages = const [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(apiRepositoryProvider);
      final services = await repo.getAddonServices(gymId);
      List<Map<String, dynamic>> usages = const [];
      try {
        usages = await repo.getAddonUsages(gymId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _services = services;
        _usages = usages;
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

    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final priceCtrl = TextEditingController(
      text: ((existing?['price'] as num?)?.toInt() ?? 0).toString(),
    );
    final descCtrl = TextEditingController(
      text: existing?['description'] as String? ?? '',
    );
    var type = existing?['type'] as String? ?? 'RENTAL';
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
                existing == null ? 'Tambah Add-On / Rental' : 'Edit Layanan',
                style: GoogleFonts.figtree(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Layanan *'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: type,
                      dropdownColor: AppColors.card,
                      decoration: const InputDecoration(labelText: 'Tipe'),
                      items: const [
                        DropdownMenuItem(value: 'RENTAL', child: Text('Rental')),
                        DropdownMenuItem(
                          value: 'CONSUMABLE',
                          child: Text('Consumable'),
                        ),
                        DropdownMenuItem(value: 'SERVICE', child: Text('Layanan')),
                      ],
                      onChanged: (v) {
                        if (v != null) setModalState(() => type = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Harga (Rp)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Deskripsi'),
              ),
              SwitchListTile(
                value: isActive,
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.accent,
                title: const Text('Aktif'),
                onChanged: (v) => setModalState(() => isActive = v),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          final messenger = ScaffoldMessenger.of(ctx);
                          setModalState(() => saving = true);
                          try {
                            final repo = ref.read(apiRepositoryProvider);
                            final payload = {
                              'name': nameCtrl.text.trim(),
                              'type': type,
                              'price': int.tryParse(priceCtrl.text.trim()) ?? 0,
                              'description': descCtrl.text.trim(),
                              'isActive': isActive,
                            };
                            if (existing == null) {
                              await repo.createAddonService(gymId, payload);
                            } else {
                              await repo.updateAddonService(
                                (existing['id'] as num).toInt(),
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
                  child: Text(saving ? 'Menyimpan...' : 'Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    nameCtrl.dispose();
    priceCtrl.dispose();
    descCtrl.dispose();
    if (saved == true) await _load();
  }

  Future<void> _deleteService(int id) async {
    try {
      await ref.read(apiRepositoryProvider).deleteAddonService(id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.parse(e)), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _returnUsage(int usageId) async {
    try {
      await ref.read(apiRepositoryProvider).returnAddonUsage(usageId);
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
        title: Text(l10n.menuAddonServices),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus, color: AppColors.accent),
            onPressed: () => _openEditor(),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(text: 'Katalog Layanan'),
            Tab(text: 'Penggunaan & Rental'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                )
              : TabBarView(
                  controller: _tab,
                  children: [
                    RefreshIndicator(
                      color: AppColors.accent,
                      backgroundColor: AppColors.card,
                      onRefresh: _load,
                      child: _services.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 120),
                                Center(
                                  child: Text(
                                    'Belum ada layanan Add-On & Rental',
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _services.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final s = _services[i];
                                final price = (s['price'] as num?)?.toDouble() ?? 0;
                                final activeRentals =
                                    (s['activeRentalsCount'] as num?)?.toInt() ?? 0;
                                final active = s['isActive'] as bool? ?? true;
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.card,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              s['name'] as String? ?? '-',
                                              style: GoogleFonts.figtree(
                                                color: AppColors.textPrimary,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${s['type'] ?? 'RENTAL'} • ${formatCurrency(price)}',
                                              style: const TextStyle(
                                                color: AppColors.accent,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (activeRentals > 0)
                                              Padding(
                                                padding:
                                                    const EdgeInsets.only(top: 4),
                                                child: Text(
                                                  '$activeRentals sedang disewa',
                                                  style: const TextStyle(
                                                    color: AppColors.secondary,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: active
                                              ? AppColors.successPillBg
                                              : AppColors.cardHover,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          active ? 'Aktif' : 'Nonaktif',
                                          style: TextStyle(
                                            color: active
                                                ? AppColors.successPillText
                                                : AppColors.textMuted,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          LucideIcons.pencil,
                                          size: 16,
                                          color: AppColors.textSecondary,
                                        ),
                                        onPressed: () => _openEditor(s),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          LucideIcons.trash2,
                                          size: 16,
                                          color: AppColors.error,
                                        ),
                                        onPressed: () => _deleteService(
                                          (s['id'] as num).toInt(),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    RefreshIndicator(
                      color: AppColors.accent,
                      backgroundColor: AppColors.card,
                      onRefresh: _load,
                      child: _usages.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 120),
                                Center(
                                  child: Text(
                                    'Belum ada catatan penggunaan add-on',
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _usages.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final u = _usages[i];
                                final status = u['status'] as String? ?? '';
                                final memberName =
                                    (u['Member'] as Map?)?['name'] as String? ??
                                        u['memberName'] as String? ??
                                        '-';
                                final serviceName = (u['AddOnService']
                                            as Map?)?['name'] as String? ??
                                    u['serviceName'] as String? ??
                                    'Add-on';
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.card,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              serviceName,
                                              style: GoogleFonts.figtree(
                                                color: AppColors.textPrimary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Member: $memberName • $status',
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (status == 'ACTIVE')
                                        OutlinedButton(
                                          onPressed: () => _returnUsage(
                                            (u['id'] as num).toInt(),
                                          ),
                                          child: const Text('Kembalikan'),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
