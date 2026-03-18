import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/utils/format.dart';
import 'member_detail_screen.dart';

class RenewMemberScreen extends ConsumerStatefulWidget {
  const RenewMemberScreen({super.key, required this.memberId});
  final int memberId;
  @override
  ConsumerState<RenewMemberScreen> createState() => _RenewMemberScreenState();
}

class _RenewMemberScreenState extends ConsumerState<RenewMemberScreen> {
  List<MembershipPackage> _packages = [];
  Member? _member;
  int? _selectedPkg;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) { setState(() => _loading = false); return; }
    try {
      final results = await Future.wait([
        ref.read(apiRepositoryProvider).getPackages(gymId),
        ref.read(apiRepositoryProvider).getMemberDetail(widget.memberId),
      ]);
      final pkgs = results[0] as List<MembershipPackage>;
      final member = results[1] as Member;
      setState(() {
        _packages = pkgs;
        _member = member;
        // Pre-select current package
        if (member.packageId != null) _selectedPkg = member.packageId;
        _loading = false;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat data: $e'), backgroundColor: AppColors.error));
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedPkg == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih paket membership')));
      return;
    }
    setState(() => _submitting = true);
    try {
      // Use packageId + renew:true as per RN implementation
      await ref.read(apiRepositoryProvider).updateMember(widget.memberId, {
        'packageId': _selectedPkg,
        'renew': true,
      });
      if (mounted) {
        ref.invalidate(memberDetailProvider(widget.memberId));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Membership berhasil diperpanjang'), backgroundColor: AppColors.success));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Perpanjang Membership'),
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop())),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Current status
        if (_member != null) _infoCard(_member!),
        const SizedBox(height: 12),

        // Package selection
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('PILIH PAKET BARU', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            ..._packages.map((p) => _PkgTile(pkg: p, selected: _selectedPkg == p.id, onTap: () => setState(() => _selectedPkg = p.id))),
          ]),
        ),
        const SizedBox(height: 20),

        SizedBox(height: 52, child: ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('🔄 Perpanjang Sekarang'),
        )),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _infoCard(Member m) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('STATUS SAAT INI', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        _row('Member', m.name),
        _row('Paket Aktif', m.packageName ?? '-'),
        _row('Expired', formatDate(m.endDate), valueColor: AppColors.error),
      ]),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
        Text(value, style: TextStyle(color: valueColor ?? AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
      ]),
    );
  }
}

class _PkgTile extends StatelessWidget {
  const _PkgTile({required this.pkg, required this.selected, required this.onTap});
  final MembershipPackage pkg;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withAlpha(25) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.accent.withAlpha(127) : AppColors.border, width: selected ? 1.5 : 1),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pkg.name, style: TextStyle(color: selected ? AppColors.accent : AppColors.textPrimary, fontWeight: FontWeight.w600)),
            Text('${pkg.durationMonths} bulan', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
          Text('Rp ${pkg.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
              style: TextStyle(color: selected ? AppColors.accent : AppColors.textPrimary, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
