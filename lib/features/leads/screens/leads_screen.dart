import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/utils/error_handler.dart';
import '../../../shared/widgets/drawer_menu_button.dart';

class LeadsScreen extends ConsumerStatefulWidget {
  const LeadsScreen({super.key});

  @override
  ConsumerState<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends ConsumerState<LeadsScreen> {
  static const _stages = <(String, String)>[
    ('ALL', 'Semua'),
    ('NEW_LEAD', 'Lead Baru'),
    ('CONTACTED', 'Dihubungi'),
    ('SCHEDULED_TRIAL', 'Jadwal Trial'),
    ('TRIAL_COMPLETED', 'Trial Selesai'),
    ('NEGOTIATION', 'Negosiasi'),
    ('CLOSED_WON', 'Berhasil'),
    ('CLOSED_LOST', 'Batal'),
  ];

  static const _sources = <String>[
    'Walk-in',
    'WhatsApp',
    'Instagram',
    'Website',
    'Referral',
    'Ads',
  ];

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _selectedStage = 'ALL';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _leads = const [];
  Map<String, dynamic> _summary = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
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
      final res = await ref.read(apiRepositoryProvider).getLeads(
            gymId,
            stage: _selectedStage,
            search: _searchCtrl.text,
          );
      final rawLeads = res['leads'] as List? ?? const [];
      if (!mounted) return;
      setState(() {
        _leads = rawLeads.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _summary = res['summary'] is Map
            ? Map<String, dynamic>.from(res['summary'] as Map)
            : const {};
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.parse(e);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _stageLabel(String stage) {
    for (final s in _stages) {
      if (s.$1 == stage) return s.$2;
    }
    return stage;
  }

  Color _stageColor(String stage) {
    switch (stage) {
      case 'CLOSED_WON':
        return AppColors.success;
      case 'CLOSED_LOST':
        return AppColors.error;
      case 'SCHEDULED_TRIAL':
      case 'TRIAL_COMPLETED':
        return AppColors.secondary;
      case 'NEGOTIATION':
        return AppColors.warning;
      default:
        return AppColors.accent;
    }
  }

  Future<void> _openEditor([Map<String, dynamic>? existing]) async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;

    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone'] as String? ?? '');
    final emailCtrl = TextEditingController(text: existing?['email'] as String? ?? '');
    final goalCtrl = TextEditingController(
      text: existing?['fitnessGoal'] as String? ?? 'General Fitness',
    );
    final notesCtrl = TextEditingController(text: existing?['notes'] as String? ?? '');
    var source = existing?['source'] as String? ?? _sources.first;
    if (!_sources.contains(source)) source = _sources.first;
    var stage = existing?['stage'] as String? ?? 'NEW_LEAD';
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
                  existing == null ? 'Tambah Prospek Baru' : 'Edit Prospek',
                  style: GoogleFonts.figtree(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Lengkap *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Nomor WhatsApp *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email (opsional)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: source,
                        dropdownColor: AppColors.card,
                        decoration: const InputDecoration(labelText: 'Sumber'),
                        items: _sources
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setModalState(() => source = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: stage,
                        dropdownColor: AppColors.card,
                        decoration: const InputDecoration(labelText: 'Tahap'),
                        items: _stages
                            .where((s) => s.$1 != 'ALL')
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.$1,
                                child: Text(s.$2, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setModalState(() => stage = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: goalCtrl,
                  decoration: const InputDecoration(labelText: 'Target Kebugaran'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Catatan'),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (nameCtrl.text.trim().isEmpty ||
                                phoneCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Nama dan nomor WhatsApp wajib diisi'),
                                ),
                              );
                              return;
                            }
                            final messenger = ScaffoldMessenger.of(ctx);
                            setModalState(() => saving = true);
                            try {
                              final payload = <String, dynamic>{
                                'name': nameCtrl.text.trim(),
                                'phone': phoneCtrl.text.trim(),
                                'email': emailCtrl.text.trim(),
                                'source': source,
                                'stage': stage,
                                'fitnessGoal': goalCtrl.text.trim(),
                                'notes': notesCtrl.text.trim(),
                              };
                              final repo = ref.read(apiRepositoryProvider);
                              if (existing == null) {
                                await repo.createLead(gymId, payload);
                              } else {
                                await repo.updateLead(
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
                    child: Text(saving ? 'Menyimpan...' : 'Simpan Prospek'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    goalCtrl.dispose();
    notesCtrl.dispose();

    if (saved == true) {
      await _load();
    }
  }

  Future<void> _updateStage(Map<String, dynamic> lead, String nextStage) async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    try {
      await ref.read(apiRepositoryProvider).updateLead(
        (lead['id'] as num).toInt(),
        gymId,
        {'stage': nextStage},
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.parse(e)), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _archiveLead(Map<String, dynamic> lead) async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    try {
      await ref.read(apiRepositoryProvider).deleteLead(
        (lead['id'] as num).toInt(),
        gymId,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.parse(e)), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final normalized = digits.startsWith('0') ? '62${digits.substring(1)}' : digits;
    final uri = Uri.parse('https://wa.me/$normalized');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final total = (_summary['total'] as num?)?.toInt() ?? _leads.length;
    final newLeads = (_summary['newLeads'] as num?)?.toInt() ?? 0;
    final inProgress = (_summary['inProgress'] as num?)?.toInt() ?? 0;
    final winRate = (_summary['winRate'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: Text(l10n.menuLeads),
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
                _KpiMiniCard(label: 'Total', value: '$total'),
                const SizedBox(width: 8),
                _KpiMiniCard(label: 'Baru', value: '$newLeads'),
                const SizedBox(width: 8),
                _KpiMiniCard(label: 'Proses', value: '$inProgress'),
                const SizedBox(width: 8),
                _KpiMiniCard(
                  label: 'Win Rate',
                  value: '$winRate%',
                  highlight: true,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), _load);
              },
              decoration: InputDecoration(
                hintText: 'Cari nama, nomor WA, atau catatan...',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(LucideIcons.x, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          _load();
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _stages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, idx) {
                final (key, label) = _stages[idx];
                final active = _selectedStage == key;
                return ChoiceChip(
                  label: Text(label),
                  selected: active,
                  selectedColor: AppColors.accentPill,
                  backgroundColor: AppColors.card,
                  labelStyle: TextStyle(
                    color: active ? AppColors.accent : AppColors.textSecondary,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: active ? AppColors.accent : AppColors.border,
                  ),
                  onSelected: (_) {
                    setState(() => _selectedStage = key);
                    _load();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
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
                            const SizedBox(height: 80),
                            Center(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: AppColors.error),
                              ),
                            ),
                          ],
                        )
                      : _leads.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 100),
                                Center(
                                  child: Text(
                                    'Belum ada prospek di tahap ini',
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: _leads.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, idx) {
                                final lead = _leads[idx];
                                final stage =
                                    lead['stage'] as String? ?? 'NEW_LEAD';
                                final color = _stageColor(stage);
                                final phone = lead['phone'] as String? ?? '';
                                final source = lead['source'] as String? ?? '-';
                                final goal =
                                    lead['fitnessGoal'] as String? ?? '';
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
                                              lead['name'] as String? ?? '-',
                                              style: GoogleFonts.figtree(
                                                color: AppColors.textPrimary,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 9,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: color.withValues(alpha: 0.14),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              _stageLabel(stage),
                                              style: TextStyle(
                                                color: color,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            color: AppColors.surface,
                                            icon: const Icon(
                                              LucideIcons.moreVertical,
                                              size: 18,
                                              color: AppColors.textSecondary,
                                            ),
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _openEditor(lead);
                                              } else if (value == 'delete') {
                                                _archiveLead(lead);
                                              } else {
                                                _updateStage(lead, value);
                                              }
                                            },
                                            itemBuilder: (_) => [
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Text('Edit Prospek'),
                                              ),
                                              ..._stages
                                                  .where(
                                                    (s) =>
                                                        s.$1 != 'ALL' &&
                                                        s.$1 != stage,
                                                  )
                                                  .map(
                                                    (s) => PopupMenuItem(
                                                      value: s.$1,
                                                      child: Text(
                                                        'Pindah ke ${s.$2}',
                                                      ),
                                                    ),
                                                  ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Text(
                                                  'Arsipkan',
                                                  style: TextStyle(
                                                    color: AppColors.error,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                            LucideIcons.phone,
                                            size: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            phone,
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            '• $source',
                                            style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (goal.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Target: $goal',
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          if (phone.isNotEmpty)
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _openWhatsApp(phone),
                                              icon: const Icon(
                                                LucideIcons.messageCircle,
                                                size: 14,
                                                color: AppColors.success,
                                              ),
                                              label: const Text(
                                                'WhatsApp',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                            ),
                                          const Spacer(),
                                          TextButton(
                                            onPressed: () => _openEditor(lead),
                                            child: const Text('Edit'),
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

class _KpiMiniCard extends StatelessWidget {
  const _KpiMiniCard({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: highlight ? AppColors.accentPill : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlight ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.figtree(
                color: highlight ? AppColors.accent : AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
