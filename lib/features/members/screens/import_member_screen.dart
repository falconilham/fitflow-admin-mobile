import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';

class ImportMemberScreen extends ConsumerStatefulWidget {
  const ImportMemberScreen({super.key});
  @override
  ConsumerState<ImportMemberScreen> createState() => _ImportMemberScreenState();
}

class _ImportMemberScreenState extends ConsumerState<ImportMemberScreen> {
  final _memberIdCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _joinDateCtrl = TextEditingController();
  final _endDateCtrl = TextEditingController();

  List<MembershipPackage> _packages = [];
  int? _selectedPkg;
  int _pkgPrice = 0;
  bool _loading = false;
  bool _pkgLoading = true;
  bool _generatingId = false;

  @override
  void initState() {
    super.initState();
    _fetchPackages();
  }

  @override
  void dispose() {
    for (final c in [_memberIdCtrl, _nameCtrl, _emailCtrl, _phoneCtrl, _addressCtrl, _joinDateCtrl, _endDateCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _fetchPackages() async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) { setState(() => _pkgLoading = false); return; }
    try {
      final pkgs = await ref.read(apiRepositoryProvider).getPackages(gymId);
      setState(() { _packages = pkgs; _pkgLoading = false; });
    } catch (e) {
      setState(() => _pkgLoading = false);
    }
  }

  Future<void> _generateId() async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    setState(() => _generatingId = true);
    try {
      final id = await ref.read(apiRepositoryProvider).generateMemberId(gymId);
      _memberIdCtrl.text = id;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal generate ID: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _generatingId = false);
    }
  }

  bool _validateDates() {
    final dateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!dateRe.hasMatch(_joinDateCtrl.text) || !dateRe.hasMatch(_endDateCtrl.text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Format tanggal harus YYYY-MM-DD')));
      return false;
    }
    if (DateTime.parse(_endDateCtrl.text).isBefore(DateTime.parse(_joinDateCtrl.text))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End Date harus setelah Join Date')));
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama wajib diisi'))); return; }
    if (_joinDateCtrl.text.isEmpty || _endDateCtrl.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Join Date dan End Date wajib diisi'))); return; }
    if (_selectedPkg == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih paket membership'))); return; }
    if (!_validateDates()) return;
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(apiRepositoryProvider).importMembers(gymId, {
        if (_memberIdCtrl.text.isNotEmpty) 'memberId': _memberIdCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'packageId': _selectedPkg,
        'price': _pkgPrice,
        'priceOverride': false,
        'paymentMethod': 'Cash',
        'joinDate': _joinDateCtrl.text.trim(),
        'endDate': _endDateCtrl.text.trim(),
        'skipEmailVerification': true,
        'recordTransaction': false,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member lama berhasil diimport'), backgroundColor: AppColors.success));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Import Member Lama'),
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop())),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _section('Informasi Member', [
          _label('Member ID (Opsional)'),
          Row(children: [
            Expanded(child: _field(_memberIdCtrl, 'e.g. M-001')),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _generatingId ? null : _generateId,
                child: _generatingId ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('Auto')),
          ]),
          const SizedBox(height: 12),
          _label('Nama Lengkap *'), _field(_nameCtrl, 'John Doe'),
          const SizedBox(height: 12),
          _label('Email'), _field(_emailCtrl, 'john@email.com', type: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _label('No. HP'), _field(_phoneCtrl, '08xxxxxxxxxx', type: TextInputType.phone),
          const SizedBox(height: 12),
          _label('Alamat (Opsional)'), _field(_addressCtrl, 'Alamat lengkap...', maxLines: 2),
        ]),
        const SizedBox(height: 12),
        _section('Tanggal Membership *', [
          _label('Join Date (YYYY-MM-DD) *'), _field(_joinDateCtrl, '2024-01-01'),
          const SizedBox(height: 12),
          _label('End Date (YYYY-MM-DD) *'), _field(_endDateCtrl, '2025-01-01'),
        ]),
        const SizedBox(height: 12),
        _section('Pilih Paket (Referensi) *', [
          if (_pkgLoading) const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
          else if (_packages.isEmpty) const Text('Belum ada paket di gym ini', style: TextStyle(color: AppColors.textMuted))
          else ..._packages.map((p) => _PkgTile(
              pkg: p, selected: _selectedPkg == p.id,
              onTap: () => setState(() { _selectedPkg = p.id; _pkgPrice = p.price; }))),
        ]),
        const SizedBox(height: 20),
        SizedBox(height: 52, child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('Import Member Lama'),
        )),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _section(String title, List<Widget> children) => Container(
      margin: const EdgeInsets.only(bottom: 0), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(), style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 14), ...children,
      ]));

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)));

  Widget _field(TextEditingController ctrl, String hint, {TextInputType type = TextInputType.text, int maxLines = 1}) =>
      TextField(controller: ctrl, keyboardType: type, maxLines: maxLines,
          style: const TextStyle(color: AppColors.textPrimary), decoration: InputDecoration(hintText: hint));
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
