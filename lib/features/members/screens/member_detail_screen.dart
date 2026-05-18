import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/utils/error_handler.dart';

final memberDetailProvider =
    FutureProvider.autoDispose.family<Member, int>((ref, memberId) async {
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
      appBar: AppBar(
        title: const Text('Detail Member'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop()),
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.card,
        onRefresh: () async => ref.invalidate(memberDetailProvider(memberId)),
        child: memberAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2)),
          error: (e, _) => Center(
              child: Text(ErrorHandler.parse(e),
                  style: const TextStyle(color: AppColors.error))),
          data: (member) => _MemberDetailBody(
            member: member,
            onRefresh: () => ref.invalidate(memberDetailProvider(memberId)),
          ),
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
  bool _archiving = false;
  bool _restoring = false;
  bool _permDeleting = false;
  bool _logging = false;

  bool get _isOwner =>
      ref.read(authProvider).valueOrNull?.admin?.isOwner ?? false;

  int? get _gymId => ref.read(authProvider).valueOrNull?.activeGymId;

  // ── Archive (soft delete) ──────────────────────────────────────────────
  Future<void> _archive() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Archive Member?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Member dengan history akan diarsipkan (data history tetap aman). '
          'Member tanpa history akan dihapus permanen.\n\n'
          'Setelah diarsipkan, member tidak bisa check-in lagi.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive',
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _archiving = true);
    try {
      await ref
          .read(apiRepositoryProvider)
          .deleteMember(widget.member.id, gymId: _gymId);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member berhasil diarsipkan')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ErrorHandler.parse(e)),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _archiving = false);
    }
  }

  // ── Restore archived member ────────────────────────────────────────────
  Future<void> _restore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Restore Member?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Member akan dikembalikan ke status Active atau Expired '
          '(tergantung tanggal expiry). Transaksi terkait juga ikut dipulihkan.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore',
                style: TextStyle(
                    color: AppColors.success, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _restoring = true);
    try {
      await ref
          .read(apiRepositoryProvider)
          .restoreMember(widget.member.id, gymId: _gymId);
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member berhasil dipulihkan')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ErrorHandler.parse(e)),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  // ── Permanent delete (owner only) ──────────────────────────────────────
  Future<void> _permanentDelete() async {
    final nameCtrl = TextEditingController();
    final required = widget.member.name.trim();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Hapus Permanen?',
              style: TextStyle(color: AppColors.error)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aksi ini TIDAK BISA dibatalkan. Semua check-in, booking, '
                'session, dan trainer package akan ikut dihapus. Transaksi keuangan '
                'tetap dipertahankan untuk audit.',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'Ketik nama member "$required" untuk konfirmasi:',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                onChanged: (_) => setSt(() {}),
                decoration: InputDecoration(
                  hintText: required,
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal')),
            TextButton(
              onPressed: nameCtrl.text.trim() == required
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Hapus Permanen',
                  style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    setState(() => _permDeleting = true);
    try {
      await ref
          .read(apiRepositoryProvider)
          .permanentDeleteMember(widget.member.id, gymId: _gymId);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member dihapus permanen')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ErrorHandler.parse(e)),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _permDeleting = false);
    }
  }

  // ── Suspend / unsuspend with reason + optional auto-reactivate date ────
  Future<void> _toggleSuspend() async {
    final m = widget.member;
    if (m.suspended) {
      // Unsuspend (no extra inputs)
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Aktifkan Member?',
              style: TextStyle(color: AppColors.textPrimary)),
          content: const Text('Member ini akan bisa check-in lagi.',
              style: TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Aktifkan',
                    style: TextStyle(color: AppColors.success))),
          ],
        ),
      );
      if (confirm != true) return;
      setState(() => _suspending = true);
      try {
        await ref
            .read(apiRepositoryProvider)
            .suspendMember(m.id, suspended: false);
        widget.onRefresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(ErrorHandler.parse(e)),
                backgroundColor: AppColors.error),
          );
        }
      } finally {
        if (mounted) setState(() => _suspending = false);
      }
      return;
    }

    // Suspend flow with reason + optional auto-reactivate date
    final reasonCtrl = TextEditingController();
    DateTime? endDate;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<_SuspendInput>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Suspend Member',
              style: TextStyle(color: AppColors.textPrimary)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Member tidak akan bisa check-in selama disuspend.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: reasonCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    autofocus: true,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Alasan Suspend',
                      hintText: 'Contoh: Tunggakan pembayaran',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Alasan wajib diisi'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Aktif kembali otomatis pada',
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12)),
                      ),
                      if (endDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              color: AppColors.textMuted, size: 18),
                          onPressed: () => setSt(() => endDate = null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endDate ??
                            DateTime.now().add(const Duration(days: 7)),
                        firstDate:
                            DateTime.now().add(const Duration(days: 1)),
                        lastDate: DateTime.now()
                            .add(const Duration(days: 365 * 2)),
                        builder: (ctx2, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppColors.accent,
                              onPrimary: Colors.black,
                              surface: AppColors.card,
                              onSurface: AppColors.textPrimary,
                            ),
                            dialogTheme: const DialogThemeData(
                                backgroundColor: AppColors.card),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) setSt(() => endDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 16, color: AppColors.accent),
                          const SizedBox(width: 8),
                          Text(
                            endDate != null
                                ? DateFormat('d MMM yyyy', 'id_ID')
                                    .format(endDate!)
                                : 'Pilih tanggal (opsional)',
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(
                      context,
                      _SuspendInput(
                        reason: reasonCtrl.text.trim(),
                        endDate: endDate,
                      ));
                }
              },
              child: const Text('Suspend'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    setState(() => _suspending = true);
    try {
      await ref.read(apiRepositoryProvider).suspendMember(
            m.id,
            suspended: true,
            reason: result.reason,
            endDate: result.endDate != null
                ? DateFormat('yyyy-MM-dd').format(result.endDate!)
                : null,
          );
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ErrorHandler.parse(e)),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _suspending = false);
    }
  }


  Future<void> _logVisit() async {
    final m = widget.member;
    final defaultDuration =
        (m.sessionDuration ?? 0) > 0 ? m.sessionDuration : null;

    final minutesController = TextEditingController(
      text: defaultDuration != null ? defaultDuration.toString() : '',
    );
    final formKey = GlobalKey<FormState>();

    final used = await showDialog<int?>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Log Kunjungan',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Catat kunjungan manual. Saldo menit/sesi akan dikurangi.',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: minutesController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: AppColors.textPrimary),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Durasi (menit)',
                  suffixText: 'menit',
                ),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) return 'Masukkan angka > 0';
                  final remaining = m.remainingMinutes ?? 0;
                  if (remaining > 0 && n > remaining) {
                    return 'Sisa saldo hanya $remaining menit';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(
                    context, int.parse(minutesController.text.trim()));
              }
            },
            child: const Text('Catat'),
          ),
        ],
      ),
    );

    if (used == null || used <= 0) return;

    setState(() => _logging = true);
    try {
      await ref
          .read(apiRepositoryProvider)
          .logMemberVisit(m.id, minutesUsed: used);
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kunjungan tercatat ($used menit)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ErrorHandler.parse(e)),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  String _daysLeftText(String endDateStr) {
    try {
      final end = DateTime.parse(endDateStr);
      final now = DateTime.now();
      final diff = end.difference(now).inDays;
      if (diff < 0) return '';
      return '${diff}d left';
    } catch (_) {
      return '';
    }
  }

  bool _isExpired(String endDateStr) {
    try {
      return DateTime.parse(endDateStr).isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final features = ref.watch(authProvider).valueOrNull?.admin?.gym?.features ?? [];
    final hasSessionPackages = features.contains('session_packages');
    final m = widget.member;
    final isArchived = m.isArchived;
    final expired = _isExpired(m.endDate);
    final isActive = !isArchived && !m.suspended && m.status.toLowerCase() == 'active' && !expired;
    final statusColor = isArchived
        ? AppColors.textMuted
        : m.suspended
            ? AppColors.error
            : isActive
                ? AppColors.success
                : AppColors.error;
    final statusText = m.displayStatus;

    final totalSessions = m.totalSessions ?? 0;
    final usedSessions = m.usedSessions ?? 0;
    final hasQuota = !isArchived && hasSessionPackages &&
        (totalSessions > 0 ||
            (m.totalMinutes ?? 0) > 0 ||
            m.hasVisitPackage);
    final sessionProgress = totalSessions > 0
        ? (usedSessions / totalSessions).clamp(0.0, 1.0)
        : 0.0;

    return ListView(padding: const EdgeInsets.all(16), children: [
      // ── Profile header ──────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.surface,
              backgroundImage:
                  m.memberPhoto != null && m.memberPhoto!.isNotEmpty
                      ? NetworkImage(m.memberPhoto!)
                      : null,
              child: m.memberPhoto == null || m.memberPhoto!.isEmpty
                  ? Text(
                      (m.name.isNotEmpty ? m.name[0] : '?').toLowerCase(),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      )),
                  if (m.memberId != null) ...[
                    const SizedBox(height: 2),
                    Text('ID: ${m.memberId}',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        )),
                  ],
                  if (m.email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(m.email,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        )),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(30),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor.withAlpha(80)),
              ),
              child: Text(statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  )),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),

      // Suspension info card
      if (m.suspended && !isArchived) _SuspensionBanner(member: m),

      // ── Dates card ──────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Joined',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(formatDate(m.joinDate),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      )),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Expires',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(formatDate(m.endDate),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          )),
                      const SizedBox(width: 8),
                      if (expired)
                        const Text('!',
                            style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ))
                      else if (_daysLeftText(m.endDate).isNotEmpty)
                        Text(_daysLeftText(m.endDate),
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            )),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),

      // ── Package card ────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withAlpha(60)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Package',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.packageName ?? '-',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          )),
                      if (m.packagePrice != null) ...[
                        const SizedBox(height: 4),
                        Text('Rp ${formatPrice(m.packagePrice!)}',
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            )),
                      ],
                    ],
                  ),
                ),
                if (!isArchived)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      backgroundColor: AppColors.accent.withAlpha(20),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.autorenew_rounded, size: 16),
                    label: const Text(
                      'Perpanjang',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: () async {
                      await context.push('/members/${m.id}/renew');
                      widget.onRefresh();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),

      // ── Sessions Used ───────────────────────────────────────────
      if (!isArchived && totalSessions > 0) ...[
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sessions Used',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              Text('$usedSessions / $totalSessions',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  )),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: sessionProgress,
            minHeight: 6,
            backgroundColor: AppColors.surface,
            valueColor: AlwaysStoppedAnimation(
              sessionProgress < 0.7
                  ? AppColors.accent
                  : sessionProgress < 0.9
                      ? AppColors.warning
                      : AppColors.error,
            ),
          ),
        ),
      ],

      // ── Log Visit button (only for quota-based packages) ─────────
      if (!isArchived && isActive && !m.suspended && hasQuota) ...[
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _logging ? null : _logVisit,
            child: _logging
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : const Text('Log Visit',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    )),
          ),
        ),
      ],
      const SizedBox(height: 20),

      // ── Actions ─────────────────────────────────────────────────
      if (isArchived) ...[
        if (_isOwner) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              icon: _restoring
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.restore_rounded),
              label: const Text('Restore Member'),
              onPressed: _restoring ? null : _restore,
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            icon: const Icon(Icons.delete_forever_rounded,
                color: AppColors.error, size: 20),
            label: _permDeleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.error))
                : const Text('Hapus Permanen',
                    style: TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
            onPressed: _permDeleting ? null : _permanentDelete,
          ),
        ] else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Member ini diarsipkan. Restore & Hapus Permanen hanya bisa dilakukan oleh Owner.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
      ] else ...[
        // Bottom action row: Edit | Suspend | Delete
        Row(
          children: [
            // Edit button
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                key: const ValueKey('edit_member_button'),
                icon: const Icon(Icons.edit_note_rounded,
                    color: AppColors.textSecondary),
                onPressed: () => context.push('/members/${m.id}/edit'),
              ),
            ),
            const SizedBox(width: 8),
            // Suspend button
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      m.suspended ? AppColors.success : AppColors.warning,
                  side: BorderSide(
                      color: m.suspended
                          ? AppColors.success.withAlpha(120)
                          : AppColors.warning.withAlpha(120)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: _suspending
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: m.suspended
                                ? AppColors.success
                                : AppColors.warning))
                    : Icon(
                        m.suspended
                            ? Icons.check_circle_outline_rounded
                            : Icons.block_rounded,
                        size: 18,
                      ),
                label: Text(m.suspended ? 'Activate' : 'Suspend',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                onPressed: _suspending ? null : _toggleSuspend,
              ),
            ),
            const SizedBox(width: 8),
            // Delete button
            if (_isOwner)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(20),
                  border: Border.all(color: AppColors.error.withAlpha(60)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: _archiving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.error))
                      : const Icon(Icons.delete_rounded, color: AppColors.error),
                  onPressed: _archiving ? null : _archive,
                ),
              ),
          ],
        ),
      ],
      const SizedBox(height: 24),
    ]);
  }
}

class _SuspendInput {
  final String reason;
  final DateTime? endDate;
  _SuspendInput({required this.reason, this.endDate});
}

class _SuspensionBanner extends StatelessWidget {
  final Member member;
  const _SuspensionBanner({required this.member});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.gpp_bad_rounded, color: AppColors.error, size: 18),
            SizedBox(width: 8),
            Text('Member sedang disuspend',
                style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
          ]),
          if (member.suspensionReason != null &&
              member.suspensionReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Alasan: ${member.suspensionReason!}',
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 12)),
          ],
          if (member.suspensionEndDate != null &&
              member.suspensionEndDate!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
                'Aktif kembali otomatis: ${formatDate(member.suspensionEndDate)}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

