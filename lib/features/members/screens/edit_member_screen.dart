import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../data/models/models.dart';
import '../../../shared/utils/error_handler.dart';
import 'member_detail_screen.dart';

class EditMemberScreen extends ConsumerStatefulWidget {
  const EditMemberScreen({super.key, required this.memberId});
  final int memberId;
  @override
  ConsumerState<EditMemberScreen> createState() => _EditMemberScreenState();
}

class _EditMemberScreenState extends ConsumerState<EditMemberScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _memberIdCtrl = TextEditingController();
  bool _loading = false;
  bool _fetching = true;
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
    try {
      final futures = [
        ref.read(apiRepositoryProvider).getMemberDetail(widget.memberId),
        if (gymId != null) ref.read(apiRepositoryProvider).getGymSettings(gymId).catchError((_) => const GymSettings()),
      ];
      final results = await Future.wait(futures);
      final m = results[0] as Member;
      _nameCtrl.text = m.name;
      _emailCtrl.text = m.email;
      _phoneCtrl.text = m.phone ?? '';
      _memberIdCtrl.text = m.memberId ?? '';
      if (results.length > 1) _settings = results[1] as GymSettings;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat data: ${ErrorHandler.parse(e)}'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _fetching = false);
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal generate ID: ${ErrorHandler.parse(e)}'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _generatingId = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ref.read(apiRepositoryProvider).updateMember(widget.memberId, {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        if (_memberIdCtrl.text.isNotEmpty) 'memberId': _memberIdCtrl.text.trim(),
      });
      if (mounted) {
        ref.invalidate(memberDetailProvider(widget.memberId));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data member berhasil diperbarui'), backgroundColor: AppColors.success));
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
    if (_fetching) return const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)));
    final emailRequired = _settings.mandatoryContact == 'email';
    final phoneRequired = _settings.mandatoryContact == 'phone';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Edit Member'),
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop())),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('INFORMASI MEMBER', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 14),

            _label('Nama Lengkap *'),
            TextField(controller: _nameCtrl, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(hintText: 'John Doe')),
            const SizedBox(height: 14),

            _label('Member ID${_settings.requireMemberId ? ' *' : ' (Opsional)'}'),
            Row(children: [
              Expanded(child: TextField(controller: _memberIdCtrl, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(hintText: 'e.g. MEM-001'))),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _generatingId ? null : _generateId,
                  child: _generatingId ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('Auto')),
            ]),
            const SizedBox(height: 14),

            _label('Email${emailRequired ? ' *' : ' (Opsional)'}'),
            TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(hintText: emailRequired ? 'john@email.com' : 'Email (Opsional)')),
            const SizedBox(height: 14),

            _label('No. HP${phoneRequired ? ' *' : ' (Opsional)'}'),
            TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(hintText: phoneRequired ? '08xxxxxxxxxx' : 'No. HP (Opsional)')),
          ]),
        ),
        const SizedBox(height: 20),
        SizedBox(height: 52, child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('Simpan Perubahan'),
        )),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)));
}
