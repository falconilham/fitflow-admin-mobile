import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/drawer_menu_button.dart';

final memberSearchProvider = StateProvider<String>((_) => '');
final memberStatusFilterProvider = StateProvider<String>((_) => 'all');
const _pageLimit = 10;

class _StatusFilter {
  final String key;
  final String label;
  final Color color;
  const _StatusFilter(this.key, this.label, this.color);
}

const _filters = <_StatusFilter>[
  _StatusFilter('all', 'All', AppColors.accent),
  _StatusFilter('active', 'Active', AppColors.success),
  _StatusFilter('expiring', 'Expiring', AppColors.warning),
  _StatusFilter('suspended', 'Suspended', AppColors.error),
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
      setState(() {
        _loading = false;
      });
      return;
    }
    _fetching = true;
    final page = reset ? 1 : _page;
    final search = ref.read(memberSearchProvider);
    final status = ref.read(memberStatusFilterProvider);
    try {
      final rows = await ref.read(apiRepositoryProvider).getMembers(
            gymId,
            search: search,
            status: status,
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
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(memberSearchProvider.notifier).state = v;
      _refresh();
    });
    setState(() {}); // For clear button visibility
  }

  void _onStatusChanged(String s) {
    ref.read(memberStatusFilterProvider.notifier).state = s;
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final statusFilter = ref.watch(memberStatusFilterProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Members'),
        actions: [
          IconButton(
              icon: const Icon(Icons.upload_file_rounded),
              tooltip: 'Import Member',
              onPressed: () => context.push(AppRoutes.importMember)),
          IconButton(
              icon: const Icon(Icons.person_add_rounded),
              tooltip: 'Add Member',
              onPressed: () => context.push(AppRoutes.addMember)),
        ],
      ),
      body: Column(children: [
        // Search row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: [
            Expanded(
                child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Cari nama, email, atau ID...',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textMuted),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            color: AppColors.textMuted),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                        })
                    : null,
              ),
              onChanged: _onSearchChanged,
            )),
          ]),
        ),
        const SizedBox(height: 10),
        // Filter chips
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f = _filters[i];
              final active = statusFilter == f.key;
              return GestureDetector(
                onTap: () => _onStatusChanged(f.key),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color:
                        active ? f.color.withAlpha(38) : AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: active
                            ? f.color.withAlpha(127)
                            : AppColors.border),
                  ),
                  child: Text(f.label,
                      style: TextStyle(
                          color: active ? f.color : AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.accent, strokeWidth: 2))
                : RefreshIndicator(
                    color: AppColors.accent,
                    backgroundColor: AppColors.card,
                    onRefresh: () async => _refresh(),
                    child: _members.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 120),
                              Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                      'Tidak ada member ditemukan',
                                      style: TextStyle(
                                          color: AppColors.textMuted)),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _members.length + (_hasMore ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              if (i == _members.length) {
                                if (!_loadingMore) {
                                  _loadingMore = true;
                                  _load();
                                }
                                return const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Center(
                                        child: CircularProgressIndicator(
                                            color: AppColors.accent,
                                            strokeWidth: 2)));
                              }
                              return _MemberCard(member: _members[i]);
                            },
                          ),
                  )),
      ]),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member});
  final Member member;
  @override
  Widget build(BuildContext context) {
    final m = member;
    final isArchived = m.isArchived;
    final isSuspended = m.suspended;
    final isExpired = m.status.toLowerCase() == 'expired';
    final isActive = m.status.toLowerCase() == 'active' && !isSuspended;

    final statusColor = isArchived
        ? AppColors.textMuted
        : isSuspended || isExpired
            ? AppColors.error
            : isActive
                ? AppColors.success
                : AppColors.warning;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/members/${m.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isArchived
                  ? AppColors.textMuted.withAlpha(60)
                  : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.accent.withAlpha(38),
                  backgroundImage:
                      m.memberPhoto != null && m.memberPhoto!.isNotEmpty
                          ? NetworkImage(m.memberPhoto!)
                          : null,
                  child: m.memberPhoto == null || m.memberPhoto!.isEmpty
                      ? Text(
                          (m.name.isNotEmpty ? m.name[0] : '?').toUpperCase(),
                          style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 14),
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
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      if (m.memberId != null)
                        Text('ID: ${m.memberId}',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11)),
                      Text(
                        '${m.packageName ?? 'No package'} · Exp: ${formatDate(m.endDate)}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _StatusBadge(label: m.displayStatus, color: statusColor),
              ],
            ),
            if (_shouldShowSessionRow(m)) ...[
              const SizedBox(height: 10),
              _SessionRow(member: m),
            ],
          ],
        ),
      ),
    );
  }

  bool _shouldShowSessionRow(Member m) {
    return m.hasVisitPackage ||
        (m.totalSessions ?? 0) > 0 ||
        (m.totalMinutes ?? 0) > 0 ||
        m.remainingPtSessions > 0;
  }
}

class _SessionRow extends StatelessWidget {
  final Member member;
  const _SessionRow({required this.member});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    // Gym session quota (PERIOD with quota / SESSION / Minute-based)
    if (member.hasVisitPackage ||
        (member.totalSessions ?? 0) > 0 ||
        (member.totalMinutes ?? 0) > 0) {
      final total = member.totalSessions ?? 0;
      final used = member.usedSessions ?? 0;
      final showSessions = total > 0;
      // For minute-based, show remaining minutes instead
      final totalMin = member.totalMinutes ?? 0;
      final usedMin = member.usedMinutes ?? 0;
      final showMinutes = !showSessions && totalMin > 0;

      if (showSessions) {
        final progress = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
        children.add(_QuotaChip(
          label: 'Gym',
          value: '${total - used}/$total',
          progress: progress,
          color: const Color(0xFF60A5FA),
        ));
      } else if (showMinutes) {
        final progress = totalMin > 0 ? (usedMin / totalMin).clamp(0.0, 1.0) : 0.0;
        children.add(_QuotaChip(
          label: 'Menit',
          value: '${totalMin - usedMin}/$totalMin',
          progress: progress,
          color: const Color(0xFF60A5FA),
        ));
      }
    }

    if (member.remainingPtSessions > 0) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 8));
      children.add(_PtChip(remaining: member.remainingPtSessions));
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Row(children: children);
  }
}

class _QuotaChip extends StatelessWidget {
  final String label;
  final String value;
  final double progress; // 0..1 used ratio
  final Color color;
  const _QuotaChip({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = progress < 0.7
        ? color
        : progress < 0.9
            ? AppColors.warning
            : AppColors.error;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
              const Spacer(),
              Text(value,
                  style: TextStyle(
                      color: barColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PtChip extends StatelessWidget {
  final int remaining;
  const _PtChip({required this.remaining});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withAlpha(80)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.fitness_center_rounded,
            size: 12, color: AppColors.accent),
        const SizedBox(width: 4),
        Text('$remaining PT',
            style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
                fontSize: 11)),
      ]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
