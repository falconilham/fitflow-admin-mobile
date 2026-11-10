import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/utils/error_handler.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/drawer_menu_button.dart';

final memberSearchProvider = StateProvider<String>((_) => '');
final memberStatusFilterProvider = StateProvider<String>((_) => 'all');
final memberSortProvider = StateProvider<String>((_) => 'joinDate');
final memberSortOrderProvider = StateProvider<String>((_) => 'desc');
final memberViewModeProvider = StateProvider<String>((_) => 'grid'); // 'grid' | 'table'

const _pageLimit = 20;

class _StatusFilter {
  final String key;
  final String label;
  final Color color;
  const _StatusFilter(this.key, this.label, this.color);
}

const _filters = <_StatusFilter>[
  _StatusFilter('all', 'All Members', AppColors.accent),
  _StatusFilter('active', 'Active Only', AppColors.success),
  _StatusFilter('expiring', 'Expiring Soon', AppColors.warning),
  _StatusFilter('suspended', 'Suspended', Color(0xFFF59E0B)),
  _StatusFilter('expired', 'Expired', AppColors.error),
  _StatusFilter('archived', 'Archived', AppColors.textMuted),
];

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});
  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  final _searchCtrl = TextEditingController();
  List<Member> _members = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  bool _fetching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_fetching) return;
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    _fetching = true;
    final page = reset ? 1 : _page;
    final search = ref.read(memberSearchProvider);
    final status = ref.read(memberStatusFilterProvider);
    final sortBy = ref.read(memberSortProvider);
    final sortOrder = ref.read(memberSortOrderProvider);

    try {
      final rows = await ref.read(apiRepositoryProvider).getMembers(
            gymId,
            search: search,
            status: status,
            sortBy: sortBy,
            sortOrder: sortOrder,
            page: page,
            limit: _pageLimit,
          );
      if (!mounted) return;
      setState(() {
        _members = reset ? rows : [..._members, ...rows];
        _page = page + 1;
        _hasMore = rows.length == _pageLimit;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      debugPrint('Members fetch error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    } finally {
      _fetching = false;
    }
  }

  void _refresh() {
    setState(() {
      _loading = true;
      _page = 1;
      _members = [];
      _hasMore = true;
    });
    _load(reset: true);
  }

  void _onSearchChanged(String v) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(memberSearchProvider.notifier).state = v;
      _refresh();
    });
    setState(() {}); // For clear button visibility
  }

  void _onStatusChanged(String s) {
    ref.read(memberStatusFilterProvider.notifier).state = s;
    _refresh();
  }

  void _onSortChanged(String by, String order) {
    ref.read(memberSortProvider.notifier).state = by;
    ref.read(memberSortOrderProvider.notifier).state = order;
    _refresh();
  }

  Future<void> _handleSuspendToggle(Member m) async {
    final isSuspended = m.suspended;
    if (isSuspended) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Aktifkan Member?', style: TextStyle(color: AppColors.textPrimary)),
          content: Text('Status suspend pada ${m.name} akan dicabut dan member dapat check-in kembali.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Aktifkan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      try {
        await ref.read(apiRepositoryProvider).suspendMember(m.id, suspended: false);
        _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Member berhasil diaktifkan kembali')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ErrorHandler.parse(e)), backgroundColor: AppColors.error),
          );
        }
      }
    } else {
      final reasonCtrl = TextEditingController();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Suspend Member', style: TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tangguhkan akses ${m.name}. Member tidak dapat check-in selama periode penangguhan.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 14),
              TextField(
                controller: reasonCtrl,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Alasan Penangguhan (Opsional)',
                  hintText: 'Misal: Cedera medis, cuti latihan...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Suspend', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      try {
        await ref.read(apiRepositoryProvider).suspendMember(
              m.id,
              suspended: true,
              reason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : null,
            );
        _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Member berhasil di-suspend')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ErrorHandler.parse(e)), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _handleArchiveOrDelete(Member m) async {
    final isArchived = m.isArchived;
    if (isArchived) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(m.name, style: const TextStyle(color: AppColors.textPrimary)),
          content: const Text(
            'Pilih tindakan untuk member yang diarsipkan ini:\n\n'
            '• Restore: Memulihkan kembali ke daftar aktif/expired.\n'
            '• Hapus Permanen: Menghapus data member & histori selamanya.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              child: const Text('Hapus Permanen', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(ctx, 'restore'),
              child: const Text('Restore', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (action == 'restore') {
        try {
          final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
          await ref.read(apiRepositoryProvider).restoreMember(m.id, gymId: gymId);
          _refresh();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Member berhasil dipulihkan')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(ErrorHandler.parse(e)), backgroundColor: AppColors.error),
            );
          }
        }
      } else if (action == 'delete') {
        try {
          final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
          await ref.read(apiRepositoryProvider).permanentDeleteMember(m.id, gymId: gymId);
          _refresh();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Member berhasil dihapus permanen')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(ErrorHandler.parse(e)), backgroundColor: AppColors.error),
            );
          }
        }
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Arsipkan Member?', style: TextStyle(color: AppColors.textPrimary)),
          content: Text(
            'Member ${m.name} akan dipindahkan ke arsip. Member tidak dapat check-in selama diarsipkan.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Arsipkan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      try {
        final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
        await ref.read(apiRepositoryProvider).deleteMember(m.id, gymId: gymId);
        _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Member berhasil diarsipkan')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ErrorHandler.parse(e)), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  void _showWaiverDetails(Member m) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              m.waiverAccepted ? LucideIcons.shieldCheck : LucideIcons.fileText,
              color: m.waiverAccepted ? AppColors.success : AppColors.error,
              size: 22,
            ),
            const SizedBox(width: 8),
            const Text('Liability Waiver', style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
            if (m.memberId != null)
              Text('ID: ${m.memberId}', style: const TextStyle(color: AppColors.accent, fontSize: 12)),
            const SizedBox(height: 12),
            _infoRow('Status Waiver', m.waiverAccepted ? 'Signed (Disetujui)' : 'Belum Ditandatangani'),
            _infoRow('Kondisi Medis (PAR-Q)', m.parqHasCondition ? 'Ada Riwayat Medis (Alert)' : 'Tidak Ada Riwayat Khusus'),
            if (m.phone != null && m.phone!.isNotEmpty) _infoRow('Kontak', m.phone!),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusFilter = ref.watch(memberStatusFilterProvider);
    final sortBy = ref.watch(memberSortProvider);
    final sortOrder = ref.watch(memberSortOrderProvider);
    final viewMode = ref.watch(memberViewModeProvider);
    final authState = ref.watch(authProvider).valueOrNull;
    final isOwner = authState?.admin?.isOwner ?? false;
    final features = authState?.admin?.gym?.features ?? [];
    final hasSessionPackages = features.contains('session_packages');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: Text(
          'Member Management',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            fontSize: 19,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.bell, size: 20),
            tooltip: 'Notifikasi',
            onPressed: () => context.push(AppRoutes.notifications),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 768;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Title & Subtitle + 2 Prominent Action Buttons (Web 1:1) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Member Management',
                      style: GoogleFonts.outfit(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: isWide ? 26 : 22,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Manage active memberships and user profiles.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Top 2 Big Action Buttons: [Import Existing] & [+ Add Member]
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.border),
                              backgroundColor: AppColors.card,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(LucideIcons.upload, size: 16),
                            label: const Text('Import Existing', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            onPressed: () => context.push(AppRoutes.importMember),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            icon: const Icon(LucideIcons.userPlus, size: 16, color: Colors.black),
                            label: const Text('Add Member', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            onPressed: () => context.push(AppRoutes.addMember),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Search Bar (Full Width like Web) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    filled: true,
                    fillColor: AppColors.card,
                    prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.textMuted),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textMuted),
                            onPressed: () {
                              _searchCtrl.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),

              // ── Filter Button (Full Width like Web Mobile) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: PopupMenuButton<String>(
                  tooltip: 'Filter Status',
                  color: AppColors.card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: _onStatusChanged,
                  itemBuilder: (ctx) => _filters.map((f) {
                    final selected = statusFilter == f.key;
                    return PopupMenuItem<String>(
                      value: f.key,
                      child: Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: f.color, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(
                            f.label,
                            style: TextStyle(
                              color: selected ? AppColors.accent : AppColors.textPrimary,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.filter, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          'Filter: ${_filters.firstWhere((f) => f.key == statusFilter, orElse: () => _filters[0]).label}',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Sort Button (Full Width like Web Mobile) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: PopupMenuButton<String>(
                  tooltip: 'Urutkan',
                  color: AppColors.card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) {
                    final parts = val.split(':');
                    _onSortChanged(parts[0], parts[1]);
                  },
                  itemBuilder: (ctx) => [
                    _sortMenuItem('createdAt:desc', 'Newest Added', (sortBy == 'createdAt' || sortBy == 'joinDate') && sortOrder == 'desc'),
                    _sortMenuItem('createdAt:asc', 'Oldest Added', (sortBy == 'createdAt' || sortBy == 'joinDate') && sortOrder == 'asc'),
                    _sortMenuItem('name:asc', 'Name (A - Z)', sortBy == 'name' && sortOrder == 'asc'),
                    _sortMenuItem('name:desc', 'Name (Z - A)', sortBy == 'name' && sortOrder == 'desc'),
                    _sortMenuItem('memberId:asc', 'Member ID (Asc)', sortBy == 'memberId' && sortOrder == 'asc'),
                    _sortMenuItem('memberId:desc', 'Member ID (Desc)', sortBy == 'memberId' && sortOrder == 'desc'),
                    _sortMenuItem('joinDate:desc', 'Joined Date (Newest)', sortBy == 'joinDate' && sortOrder == 'desc'),
                    _sortMenuItem('joinDate:asc', 'Joined Date (Oldest)', sortBy == 'joinDate' && sortOrder == 'asc'),
                    _sortMenuItem('endDate:asc', 'End Date (Expiring Soonest)', sortBy == 'endDate' && sortOrder == 'asc'),
                    _sortMenuItem('endDate:desc', 'End Date (Expiring Latest)', sortBy == 'endDate' && sortOrder == 'desc'),
                    _sortMenuItem('status:asc', 'Status', sortBy == 'status' && sortOrder == 'asc'),
                  ],
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.arrowUpDown, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          'Sort: ${_getSortLabel(sortBy, sortOrder)}',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── View Mode Switcher (Aligned to the Right like Web Mobile) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => ref.read(memberViewModeProvider.notifier).state = 'table',
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: viewMode == 'table' ? AppColors.accent : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                LucideIcons.list,
                                size: 18,
                                color: viewMode == 'table' ? Colors.black : AppColors.textMuted,
                              ),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => ref.read(memberViewModeProvider.notifier).state = 'grid',
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: viewMode == 'grid' ? AppColors.accent : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                LucideIcons.layoutGrid,
                                size: 18,
                                color: viewMode == 'grid' ? Colors.black : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Members List / Grid / Table ──
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2.5),
                      )
                    : RefreshIndicator(
                        color: AppColors.accent,
                        backgroundColor: AppColors.card,
                        onRefresh: () async => _refresh(),
                        child: _members.isEmpty
                            ? _buildEmptyState()
                            : (viewMode == 'table' && isWide)
                                ? _buildTableView(isOwner, hasSessionPackages)
                                : _buildGridView(isWide, isOwner, hasSessionPackages),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getSortLabel(String by, String order) {
    if (by == 'createdAt' || by == 'joinDate') return order == 'asc' ? 'Oldest Added' : 'Newest Added';
    if (by == 'name') return order == 'asc' ? 'Name (A - Z)' : 'Name (Z - A)';
    if (by == 'memberId') return order == 'asc' ? 'Member ID (Asc)' : 'Member ID (Desc)';
    if (by == 'endDate') return order == 'asc' ? 'End Date (Expiring Soonest)' : 'End Date (Expiring Latest)';
    return 'Status';
  }

  PopupMenuItem<String> _sortMenuItem(String val, String label, bool isSelected) {
    return PopupMenuItem<String>(
      value: val,
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: isSelected ? AppColors.accent : AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.accent : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Container(
            padding: const EdgeInsets.all(28),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.search, size: 36, color: AppColors.accent),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Members Found',
                  style: GoogleFonts.outfit(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "We couldn't find any members matching your search or filters. Try adjusting your filter, or add a new member.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(LucideIcons.userPlus, size: 16, color: Colors.black),
                  label: const Text('Add Member', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => context.push(AppRoutes.addMember),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridView(bool isWide, bool isOwner, bool hasSessionPackages) {
    final gymName = ref.read(authProvider).valueOrNull?.admin?.gym?.name ?? 'FitFlow Gym';

    if (isWide) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 440,
          mainAxisExtent: 360,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: _members.length + (_hasMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == _members.length) {
            if (!_loadingMore) {
              _loadingMore = true;
              _load();
            }
            return const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2));
          }
          return _MemberCard(
            member: _members[i],
            gymName: gymName,
            isOwner: isOwner,
            hasSessionPackages: hasSessionPackages,
            onRefresh: _refresh,
            onWaiverClick: () => _showWaiverDetails(_members[i]),
            onSuspendToggle: () => _handleSuspendToggle(_members[i]),
            onArchiveOrDelete: () => _handleArchiveOrDelete(_members[i]),
          );
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _members.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        if (i == _members.length) {
          if (!_loadingMore) {
            _loadingMore = true;
            _load();
          }
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
          );
        }
        return _MemberCard(
          member: _members[i],
          gymName: gymName,
          isOwner: isOwner,
          hasSessionPackages: hasSessionPackages,
          onRefresh: _refresh,
          onWaiverClick: () => _showWaiverDetails(_members[i]),
          onSuspendToggle: () => _handleSuspendToggle(_members[i]),
          onArchiveOrDelete: () => _handleArchiveOrDelete(_members[i]),
        );
      },
    );
  }

  Widget _buildTableView(bool isOwner, bool hasSessionPackages) {
    final gymName = ref.read(authProvider).valueOrNull?.admin?.gym?.name ?? 'FitFlow Gym';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.surface),
            headingTextStyle: GoogleFonts.outfit(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
            ),
            dataRowMaxHeight: 74,
            columnSpacing: 16,
            horizontalMargin: 16,
            columns: const [
              DataColumn(label: Text('MEMBER')),
              DataColumn(label: Text('MEMBER ID')),
              DataColumn(label: Text('STATUS')),
              DataColumn(label: Text('PAKET')),
              DataColumn(label: Text('EXPIRY / SISA')),
              DataColumn(label: Text('AKSI')),
            ],
            rows: _members.map((m) {
              return DataRow(
                onSelectChanged: (_) => context.push('/members/${m.id}'),
                cells: [
                  DataCell(
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.surface,
                          backgroundImage: m.memberPhoto != null && m.memberPhoto!.isNotEmpty
                              ? NetworkImage(m.memberPhoto!)
                              : null,
                          child: m.memberPhoto == null || m.memberPhoto!.isEmpty
                              ? Text(
                                  (m.name.isNotEmpty ? m.name[0] : '?').toLowerCase(),
                                  style: GoogleFonts.outfit(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                m.name,
                                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (m.email.isNotEmpty)
                                Text(
                                  m.email,
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      m.memberId ?? '-',
                      style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StatusBadge(status: m.displayStatus),
                        const SizedBox(width: 6),
                        _WaiverChip(waiverAccepted: m.waiverAccepted, parqHasCondition: m.parqHasCondition),
                      ],
                    ),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          m.packageName ?? '-',
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12.5),
                        ),
                        if (m.packagePrice != null && m.packagePrice! > 0)
                          Text('Rp ${formatPrice(m.packagePrice!)}', style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(m.endDate.isNotEmpty ? m.endDate : '-', style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                        _DaysLeftBadge(endDate: m.endDate, isExpired: m.displayStatus == 'Expired'),
                      ],
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _WhatsAppActionButton(member: m, gymName: gymName),
                        const SizedBox(width: 6),
                        _IconActionButton(
                          tooltip: 'Perpanjang',
                          icon: LucideIcons.refreshCw,
                          color: AppColors.accent,
                          bgColor: AppColors.accent.withAlpha(20),
                          onTap: () async {
                            await context.push('/members/${m.id}/renew');
                            _refresh();
                          },
                        ),
                        const SizedBox(width: 6),
                        _IconActionButton(
                          tooltip: 'Edit',
                          icon: LucideIcons.edit2,
                          color: AppColors.textSecondary,
                          bgColor: AppColors.surface,
                          onTap: () async {
                            await context.push('/members/${m.id}/edit');
                            _refresh();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Rich Member Card Component (Matching Web 1:1) ───────────────────────────

class _MemberCard extends StatelessWidget {
  final Member member;
  final String gymName;
  final bool isOwner;
  final bool hasSessionPackages;
  final VoidCallback onRefresh;
  final VoidCallback onWaiverClick;
  final VoidCallback onSuspendToggle;
  final VoidCallback onArchiveOrDelete;

  const _MemberCard({
    required this.member,
    required this.gymName,
    required this.isOwner,
    required this.hasSessionPackages,
    required this.onRefresh,
    required this.onWaiverClick,
    required this.onSuspendToggle,
    required this.onArchiveOrDelete,
  });

  @override
  Widget build(BuildContext context) {
    final m = member;
    final isArchived = m.isArchived;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isArchived ? AppColors.textMuted.withAlpha(60) : AppColors.border,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/members/${m.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Top Row: Avatar, Name, Member ID, Status & Waiver Chip ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.surface,
                  backgroundImage: m.memberPhoto != null && m.memberPhoto!.isNotEmpty
                      ? NetworkImage(m.memberPhoto!)
                      : null,
                  child: m.memberPhoto == null || m.memberPhoto!.isEmpty
                      ? Text(
                          (m.name.isNotEmpty ? m.name[0] : '?').toLowerCase(),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.name,
                        style: GoogleFonts.outfit(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      if (m.memberId != null && m.memberId!.isNotEmpty)
                        Text(
                          'ID: ${m.memberId}',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      if (m.email.isNotEmpty)
                        Text(
                          m.email,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatusBadge(status: m.displayStatus),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: onWaiverClick,
                      child: _WaiverChip(waiverAccepted: m.waiverAccepted, parqHasCondition: m.parqHasCondition),
                    ),
                  ],
                ),
              ],
            ),

            // ── Suspension Banner (if applicable) ──
            if (m.suspended && !isArchived) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B).withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.alertTriangle, size: 14, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ditangguhkan: ${m.suspensionReason ?? 'Tidak ada alasan'}'
                        '${m.suspensionEndDate != null ? ' (Hingga ${formatDate(m.suspensionEndDate)})' : ''}',
                        style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontStyle: FontStyle.italic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // ── Dates Grid (Joined & Expires) matching Web ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Joined', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(m.joinDate.isNotEmpty ? m.joinDate : '-', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 26, color: AppColors.border),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Expires', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(m.endDate.isNotEmpty ? m.endDate : '-', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12.5)),
                            const SizedBox(width: 6),
                            _DaysLeftBadge(endDate: m.endDate, isExpired: m.displayStatus == 'Expired'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Package Info Box (Web 1:1) ──
            if (m.packageName != null && m.packageName!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accent.withAlpha(45)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Package', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                          Text(
                            m.packageName!,
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (m.packagePrice != null && m.packagePrice! > 0)
                      Text(
                        'Rp ${formatPrice(m.packagePrice!)}',
                        style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                  ],
                ),
              ),
            ],

            // ── Sessions Usage Quota Bar ──
            if (hasSessionPackages && (m.totalSessions ?? 0) > 0) ...[
              const SizedBox(height: 8),
              _GymSessionsBar(member: m),
            ],

            // ── PT Sessions Row ──
            if (m.ptSessionTotal > 0 || m.remainingPtSessions > 0) ...[
              const SizedBox(height: 8),
              _PtSessionsRow(member: m),
            ],

            const SizedBox(height: 12),

            // ── Actions Row: WhatsApp, Extend, Edit, Waiver, Suspend, Delete (Web 1:1) ──
            Row(
              children: [
                _WhatsAppActionButton(member: m, gymName: gymName),
                const SizedBox(width: 6),
                _IconActionButton(
                  tooltip: 'Perpanjang Membership',
                  icon: LucideIcons.refreshCw,
                  color: AppColors.accent,
                  bgColor: AppColors.accent.withAlpha(25),
                  onTap: () async {
                    await context.push('/members/${m.id}/renew');
                    onRefresh();
                  },
                ),
                const SizedBox(width: 6),
                _IconActionButton(
                  tooltip: 'Edit Member',
                  icon: LucideIcons.edit2,
                  color: AppColors.textSecondary,
                  bgColor: AppColors.surface,
                  onTap: () async {
                    await context.push('/members/${m.id}/edit');
                    onRefresh();
                  },
                ),
                const SizedBox(width: 6),
                _IconActionButton(
                  tooltip: 'Lihat Surat Pernyataan / Sertifikat Waiver',
                  icon: LucideIcons.shieldCheck,
                  color: m.waiverAccepted ? const Color(0xFF38BDF8) : AppColors.error,
                  bgColor: (m.waiverAccepted ? const Color(0xFF38BDF8) : AppColors.error).withAlpha(20),
                  onTap: onWaiverClick,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _SuspendButton(
                    isSuspended: m.suspended,
                    onTap: onSuspendToggle,
                  ),
                ),
                if (isOwner) ...[
                  const SizedBox(width: 6),
                  _IconActionButton(
                    tooltip: isArchived ? 'Restore / Hapus' : 'Arsipkan Member',
                    icon: isArchived ? LucideIcons.rotateCcw : LucideIcons.trash2,
                    color: isArchived ? AppColors.success : AppColors.error,
                    bgColor: (isArchived ? AppColors.success : AppColors.error).withAlpha(20),
                    onTap: onArchiveOrDelete,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status Badges & Chips ───────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'active':
        bg = const Color(0xFF10B981).withAlpha(35);
        fg = const Color(0xFF34D399);
        icon = LucideIcons.checkCircle2;
        break;
      case 'suspended':
        bg = const Color(0xFFF59E0B).withAlpha(35);
        fg = const Color(0xFFFBBF24);
        icon = LucideIcons.ban;
        break;
      case 'expired':
        bg = const Color(0xFFEF4444).withAlpha(35);
        fg = const Color(0xFFF87171);
        icon = LucideIcons.xCircle;
        break;
      case 'archived':
      case 'deleted':
        bg = Colors.white.withAlpha(20);
        fg = AppColors.textMuted;
        icon = LucideIcons.archive;
        break;
      default:
        bg = AppColors.accent.withAlpha(30);
        fg = AppColors.accent;
        icon = LucideIcons.clock;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 3),
          Text(
            status,
            style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _WaiverChip extends StatelessWidget {
  final bool waiverAccepted;
  final bool parqHasCondition;
  const _WaiverChip({required this.waiverAccepted, required this.parqHasCondition});

  @override
  Widget build(BuildContext context) {
    if (!waiverAccepted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withAlpha(25),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFFEF4444).withAlpha(70)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.fileText, size: 9, color: Color(0xFFF87171)),
            SizedBox(width: 3),
            Text('No Waiver', style: TextStyle(color: Color(0xFFF87171), fontSize: 9.5, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    if (parqHasCondition) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withAlpha(25),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFFF59E0B).withAlpha(70)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.alertTriangle, size: 9, color: Color(0xFFFBBF24)),
            SizedBox(width: 3),
            Text('Medis', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 9.5, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withAlpha(25),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFF10B981).withAlpha(70)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.shieldCheck, size: 9, color: Color(0xFF34D399)),
          SizedBox(width: 3),
          Text('Signed', style: TextStyle(color: Color(0xFF34D399), fontSize: 9.5, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _DaysLeftBadge extends StatelessWidget {
  final String endDate;
  final bool isExpired;
  const _DaysLeftBadge({required this.endDate, required this.isExpired});

  @override
  Widget build(BuildContext context) {
    if (endDate.isEmpty) return const SizedBox.shrink();
    if (isExpired) {
      return const Text('!', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w900, fontSize: 12));
    }
    try {
      final end = DateTime.parse(endDate);
      final today = DateTime.now();
      final diff = end.difference(today).inDays;
      if (diff >= 0) {
        final color = diff <= 7 ? const Color(0xFFFBBF24) : AppColors.accent;
        return Text(
          '${diff}d left',
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11),
        );
      }
    } catch (_) {}
    return const SizedBox.shrink();
  }
}

class _GymSessionsBar extends StatelessWidget {
  final Member member;
  const _GymSessionsBar({required this.member});

  @override
  Widget build(BuildContext context) {
    final total = member.totalSessions ?? 0;
    final used = member.usedSessions ?? 0;
    final remaining = (total - used).clamp(0, total);
    final ratio = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'GYM SESSIONS',
              style: TextStyle(color: AppColors.textMuted, fontSize: 10.5, fontWeight: FontWeight.w700),
            ),
            Text(
              'Sisa $remaining / $total',
              style: const TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.bold, fontSize: 11.5),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 4,
            backgroundColor: Colors.white.withAlpha(20),
            valueColor: AlwaysStoppedAnimation(
              ratio < 0.7 ? const Color(0xFF60A5FA) : (ratio < 0.9 ? const Color(0xFFFBBF24) : AppColors.error),
            ),
          ),
        ),
      ],
    );
  }
}

class _PtSessionsRow extends StatelessWidget {
  final Member member;
  const _PtSessionsRow({required this.member});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'PT SESSIONS',
          style: TextStyle(color: AppColors.textMuted, fontSize: 10.5, fontWeight: FontWeight.w700),
        ),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${member.ptSessionCompleted}',
                style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 11.5),
              ),
              TextSpan(
                text: '/${member.ptSessionTotal} selesai',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              if (member.remainingPtSessions > 0) ...[
                const TextSpan(text: ' • ', style: TextStyle(color: AppColors.textMuted)),
                TextSpan(
                  text: '${member.remainingPtSessions} sisa',
                  style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _WhatsAppActionButton extends StatelessWidget {
  final Member member;
  final String gymName;
  const _WhatsAppActionButton({required this.member, required this.gymName});

  @override
  Widget build(BuildContext context) {
    final phone = member.phone;
    final hasPhone = phone != null && phone.trim().isNotEmpty;

    return Tooltip(
      message: hasPhone ? 'Kirim WhatsApp Promo Perpanjangan' : 'Nomor WhatsApp belum terdaftar',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: hasPhone ? () => _launchWa(context, phone, member.name, member.endDate) : null,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: hasPhone ? const Color(0xFF25D366).withAlpha(35) : Colors.white.withAlpha(8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasPhone ? const Color(0xFF25D366).withAlpha(90) : AppColors.border,
            ),
          ),
          child: Icon(
            LucideIcons.messageCircle,
            size: 16,
            color: hasPhone ? const Color(0xFF25D366) : AppColors.textMuted.withAlpha(80),
          ),
        ),
      ),
    );
  }

  Future<void> _launchWa(BuildContext context, String rawPhone, String name, String endDate) async {
    final cleanPhone = formatWhatsAppNumber(rawPhone);
    final msg = Uri.encodeComponent(
      'Halo $name! Membership Anda di $gymName akan segera berakhir pada ${formatDate(endDate)}. '
      'Yuk perpanjang sekarang untuk menikmati promo spesial dan menjaga rutinitas latihan Anda tanpa jeda!',
    );
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$msg');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }
}

class _IconActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _IconActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withAlpha(60)),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _SuspendButton extends StatelessWidget {
  final bool isSuspended;
  final VoidCallback onTap;

  const _SuspendButton({required this.isSuspended, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isSuspended ? AppColors.success : const Color(0xFFF59E0B);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSuspended ? LucideIcons.checkCircle2 : LucideIcons.ban, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              isSuspended ? 'Aktifkan' : 'Suspend',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
