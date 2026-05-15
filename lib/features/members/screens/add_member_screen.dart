import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/utils/error_handler.dart';

class AddMemberScreen extends ConsumerStatefulWidget {
  const AddMemberScreen({super.key});
  @override
  ConsumerState<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends ConsumerState<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _memberIdCtrl = TextEditingController();
  List<MembershipPackage> _packages = [];
  int? _selectedPkg;
  bool _loading = false;
  bool _pkgLoading = true;
  bool _generatingId = false;
  GymSettings _settings = const GymSettings();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose(); _memberIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) { setState(() => _pkgLoading = false); return; }
    try {
      final results = await Future.wait([
        ref.read(apiRepositoryProvider).getPackages(gymId),
        ref.read(apiRepositoryProvider).getGymSettings(gymId).catchError((_) => const GymSettings()),
      ]);
      setState(() {
        _packages = results[0] as List<MembershipPackage>;
        _settings = results[1] as GymSettings;
        _pkgLoading = false;
      });
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_settings.requireMemberId && _memberIdCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member ID wajib diisi')));
      return;
    }
    if (_selectedPkg == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih paket membership')));
      return;
    }
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(apiRepositoryProvider).createMember(gymId, {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        if (_memberIdCtrl.text.isNotEmpty) 'memberId': _memberIdCtrl.text.trim(),
        'packageId': _selectedPkg,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member berhasil ditambahkan'), backgroundColor: AppColors.success));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.parse(e)), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emailRequired = _settings.mandatoryContact == 'email';
    final phoneRequired = _settings.mandatoryContact == 'phone';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Tambah Member'),
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop())),
      body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(16), children: [
        _section('Informasi Member', [
          _label('Nama Lengkap *'),
          TextFormField(controller: _nameCtrl, style: const TextStyle(color: AppColors.textPrimary),
              validator: (v) => v!.isEmpty ? 'Nama wajib diisi' : null,
              decoration: const InputDecoration(hintText: 'John Doe')),
          const SizedBox(height: 14),

          if (_settings.requireMemberId) ...[
            _label('Member ID *'),
            Row(children: [
              Expanded(child: TextFormField(controller: _memberIdCtrl, style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(hintText: 'e.g. MEM-001'))),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _generatingId ? null : _generateId,
                  child: _generatingId ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('Auto')),
            ]),
            const SizedBox(height: 14),
          ],

          _label('Email${emailRequired ? ' *' : ' (Opsional)'}'),
          TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppColors.textPrimary),
              validator: emailRequired ? (v) => v!.isEmpty ? 'Email wajib diisi' : null : null,
              decoration: InputDecoration(hintText: emailRequired ? 'john@email.com' : 'Email (Opsional)')),
          const SizedBox(height: 14),

          _label('No. HP${phoneRequired ? ' *' : ' (Opsional)'}'),
          TextFormField(controller: _phoneCtrl, keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppColors.textPrimary),
              validator: phoneRequired ? (v) => v!.isEmpty ? 'No. HP wajib diisi' : null : null,
              decoration: InputDecoration(hintText: phoneRequired ? '08xxxxxxxxxx' : 'No. HP (Opsional)')),
        ]),
        const SizedBox(height: 12),

        _section('Pilih Paket Membership *', [
          if (_pkgLoading) const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
          else if (_packages.isEmpty) const Text('Belum ada paket di gym ini', style: TextStyle(color: AppColors.textMuted))
          else ..._packages.map((p) => _PkgTile(pkg: p, selected: _selectedPkg == p.id, onTap: () => setState(() => _selectedPkg = p.id))),
        ]),
        const SizedBox(height: 20),

        SizedBox(height: 52, child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('Simpan Member'),
        )),
        const SizedBox(height: 40),
      ])),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(), style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 14),
        ...children,
      ]),
    );
  }

  Widget _label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)));
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
