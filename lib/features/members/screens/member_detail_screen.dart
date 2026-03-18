import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../shared/utils/format.dart';

final memberDetailProvider = FutureProvider.autoDispose.family<Member, int>((ref, memberId) async {
  return ref.read(apiRepositoryProvider).getMemberDetail(memberId);
});

class MemberDetailScreen extends ConsumerWidget {
  const MemberDetailScreen({super.key, required this.memberId});
  final int memberId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberAsync = ref.watch(memberDetailProvider(memberId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Detail Member'),
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop())),
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.card,
        onRefresh: () async => ref.invalidate(memberDetailProvider(memberId)),
        child: memberAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
          error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.error))),
          data: (member) => _MemberDetailBody(member: member, onRefresh: () => ref.invalidate(memberDetailProvider(memberId))),
        ),
      ),
    );
  }
}

class _MemberDetailBody extends ConsumerStatefulWidget {
  const _MemberDetailBody({required this.member, required this.onRefresh});
  final Member member;
  final VoidCallback onRefresh;
  @override
  ConsumerState<_MemberDetailBody> createState() => _MemberDetailBodyState();
}

class _MemberDetailBodyState extends ConsumerState<_MemberDetailBody> {
  bool _suspending = false;
  bool _deleting = false;

  Future<void> _deleteMember() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Delete Member?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Are you sure you want to delete this member?\n\n'
          '• Members with history will be archived.\n'
          '• Members without history will be permanently deleted.\n'
          '• They will lose all access immediately.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _deleting = true);
    try {
      await ref.read(apiRepositoryProvider).deleteMember(widget.member.id);
      if (mounted) {
        context.pop(); // Go back to members list
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member successfully deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _toggleSuspend() async {
    final isSuspended = widget.member.suspended;
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(isSuspended ? 'Aktifkan Member?' : 'Suspend Member?',
          style: const TextStyle(color: AppColors.textPrimary)),
      content: Text(isSuspended ? 'Aktifkan kembali member ini?' : 'Member tidak bisa check-in selama disuspend.',
          style: const TextStyle(color: AppColors.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        TextButton(onPressed: () => Navigator.pop(context, true),
            child: Text(isSuspended ? 'Aktifkan' : 'Suspend', style: TextStyle(color: isSuspended ? AppColors.success : AppColors.error))),
      ],
    ));
    if (confirm != true) return;
    setState(() => _suspending = true);
    try {
      await ref.read(apiRepositoryProvider).updateMember(widget.member.id, {'suspended': !isSuspended});
      widget.onRefresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _suspending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final isActive = m.status.toLowerCase() == 'active' && !m.suspended;
    final statusColor = isActive ? AppColors.success : AppColors.error;
    final statusLabel = m.suspended ? 'Suspended' : m.status;

    return ListView(padding: const EdgeInsets.all(16), children: [
      // Profile header
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          CircleAvatar(radius: 36, backgroundColor: AppColors.accent.withAlpha(38),
              child: Text((m.name.isNotEmpty ? m.name[0] : '?').toUpperCase(),
                  style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 24))),
          const SizedBox(height: 12),
          Text(m.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
          if (m.memberId != null) ...[const SizedBox(height: 4), Text('ID: ${m.memberId}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13))],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withAlpha(38), borderRadius: BorderRadius.circular(20)),
            child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
      const SizedBox(height: 12),

      // Info
      _InfoCard(items: [
        _InfoRow(label: 'Email', value: m.email.isNotEmpty ? m.email : '-'),
        _InfoRow(label: 'Phone', value: m.phone ?? '-'),
        _InfoRow(label: 'Bergabung', value: formatDate(m.joinDate)),
        _InfoRow(label: 'Expired', value: formatDate(m.endDate)),
        _InfoRow(label: 'Paket', value: m.packageName ?? '-'),
        if (m.packagePrice != null) _InfoRow(label: 'Harga', value: formatCurrency(m.packagePrice!.toDouble())),
      ]),
      const SizedBox(height: 20),

      // Actions
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          icon: const Icon(Icons.edit_rounded),
          label: const Text('Edit'),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.accent, side: const BorderSide(color: AppColors.accent), padding: const EdgeInsets.symmetric(vertical: 13)),
          onPressed: () => context.push('/members/${m.id}/edit'),
        )),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton.icon(
          icon: const Icon(Icons.autorenew_rounded),
          label: const Text('Perpanjang'),
          onPressed: () => context.push('/members/${m.id}/renew'),
        )),
      ]),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: m.suspended ? AppColors.success.withAlpha(38) : AppColors.error.withAlpha(38),
          foregroundColor: m.suspended ? AppColors.success : AppColors.error,
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
        onPressed: _suspending ? null : _toggleSuspend,
        child: _suspending
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error))
            : Text(m.suspended ? '✅ Aktifkan' : '🚫 Suspend', style: const TextStyle(fontWeight: FontWeight.w700)),
      )),
      const SizedBox(height: 20),
      // Delete Button
      TextButton.icon(
        icon: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 20),
        label: _deleting
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error))
            : const Text('Hapus Member Secara Permanen', style: TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600)),
        onPressed: _deleting ? null : _deleteMember,
      ),
    ]);
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.items});
  final List<Widget> items;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: ListView.separated(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
        itemBuilder: (_, i) => items[i],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
        Flexible(child: Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
      ]),
    );
  }
}
