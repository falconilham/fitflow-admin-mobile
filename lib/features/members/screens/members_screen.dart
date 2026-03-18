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

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_fetching) return;
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) { setState(() { _loading = false; }); return; }
    _fetching = true;
    final page = reset ? 1 : _page;
    final search = ref.read(memberSearchProvider);
    final status = ref.read(memberStatusFilterProvider);
    try {
      final rows = await ref.read(apiRepositoryProvider).getMembers(gymId,
          search: search, status: status, page: page, limit: _pageLimit);
      setState(() {
        _members = reset ? rows : [..._members, ...rows];
        _page = page + 1;
        _hasMore = rows.length == _pageLimit;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      debugPrint('Members fetch error: $e');
      setState(() { _loading = false; _loadingMore = false; });
    } finally {
      _fetching = false;
    }
  }

  void _refresh() { setState(() { _loading = true; _page = 1; _members = []; _hasMore = true; }); _load(reset: true); }
  void _onSearchChanged(String v) { ref.read(memberSearchProvider.notifier).state = v; _refresh(); }
  void _onStatusChanged(String s) { ref.read(memberStatusFilterProvider.notifier).state = s; _refresh(); }

  @override
  Widget build(BuildContext context) {
    final statusFilter = ref.watch(memberStatusFilterProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Members'),
        actions: [
          IconButton(icon: const Icon(Icons.upload_file_rounded), onPressed: () => context.push(AppRoutes.importMember)),
          IconButton(icon: const Icon(Icons.person_add_rounded), onPressed: () => context.push(AppRoutes.addMember)),
        ],
      ),
      body: Column(children: [
        // Search row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Cari nama, email, atau ID...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear_rounded, color: AppColors.textMuted),
                        onPressed: () { _searchCtrl.clear(); _onSearchChanged(''); })
                    : null,
              ),
              onChanged: _onSearchChanged,
            )),
          ]),
        ),
        const SizedBox(height: 10),
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: ['all', 'active', 'expired', 'suspended'].map((f) {
            final active = statusFilter == f;
            final color = f == 'active' ? AppColors.success : f == 'expired' || f == 'suspended' ? AppColors.error : AppColors.accent;
            return GestureDetector(
              onTap: () => _onStatusChanged(f),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: active ? color.withAlpha(38) : AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? color.withAlpha(127) : AppColors.border),
                ),
                child: Text(f[0].toUpperCase() + f.substring(1),
                    style: TextStyle(color: active ? color : AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            );
          }).toList()),
        ),
        const SizedBox(height: 8),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
            : RefreshIndicator(
                color: AppColors.accent, backgroundColor: AppColors.card,
                onRefresh: () async => _refresh(),
                child: _members.isEmpty
                    ? const Center(child: Text('Tidak ada member ditemukan', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: _members.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          if (i == _members.length) {
                            if (!_loadingMore) { _loadingMore = true; _load(); }
                            return const Padding(padding: EdgeInsets.all(20),
                                child: Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)));
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
    final isActive = member.status.toLowerCase() == 'active' && !member.suspended;
    final isExpired = member.status.toLowerCase() == 'expired';
    final isSuspended = member.suspended;
    final color = isActive ? AppColors.success : isExpired || isSuspended ? AppColors.error : AppColors.warning;

    return GestureDetector(
      onTap: () => context.push('/members/${member.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          CircleAvatar(backgroundColor: AppColors.accent.withAlpha(38),
              child: Text((member.name.isNotEmpty ? member.name[0] : '?').toUpperCase(),
                  style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(member.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 2),
            if (member.memberId != null) Text('ID: ${member.memberId}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            Text('${member.packageName ?? 'No package'} · Exp: ${formatDate(member.endDate)}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ])),
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        ]),
      ),
    );
  }
}
