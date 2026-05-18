import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _memberIdCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _loading = false;
  bool _fetching = true;
  bool _generatingId = false;
  GymSettings _settings = const GymSettings();

  File? _imageFile;
  String? _base64Image;
  String? _existingPhotoUrl;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _memberIdCtrl.dispose();
    _addressCtrl.dispose();
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
      _addressCtrl.text = m.address ?? '';
      _existingPhotoUrl = m.memberPhoto;
      if (results.length > 1) _settings = results[1] as GymSettings;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: ${ErrorHandler.parse(e)}'), backgroundColor: AppColors.error),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal generate ID: ${ErrorHandler.parse(e)}'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingId = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageFile = File(pickedFile.path);
          _base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil gambar: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showPhotoSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.accent),
              title: const Text('Kamera', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.accent),
              title: const Text('Galeri', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_settings.requireMemberId && _memberIdCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member ID wajib diisi')));
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(apiRepositoryProvider).updateMember(widget.memberId, {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        if (_memberIdCtrl.text.isNotEmpty) 'memberId': _memberIdCtrl.text.trim(),
        if (_base64Image != null) 'memberPhoto': _base64Image,
      });
      if (mounted) {
        ref.invalidate(memberDetailProvider(widget.memberId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data member berhasil diperbarui'), backgroundColor: AppColors.success),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.parse(e)), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fetching) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
      );
    }
    final emailRequired = _settings.mandatoryContact == 'email';
    final phoneRequired = _settings.mandatoryContact == 'phone';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Member'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'INFORMASI MEMBER',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 14),

                  _label('Nama Lengkap *'),
                  TextFormField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    validator: (v) => v!.isEmpty ? 'Nama wajib diisi' : null,
                    decoration: const InputDecoration(hintText: 'John Doe'),
                  ),
                  const SizedBox(height: 14),

                  _label('Member ID${_settings.requireMemberId ? ' *' : ' (Opsional)'}'),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _memberIdCtrl,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(hintText: 'e.g. MEM-001'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _generatingId ? null : _generateId,
                        child: _generatingId
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Text('Auto'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _label('Email${emailRequired ? ' *' : ' (Opsional)'}'),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppColors.textPrimary),
                    validator: emailRequired ? (v) => v!.isEmpty ? 'Email wajib diisi' : null : null,
                    decoration: InputDecoration(hintText: emailRequired ? 'john@email.com' : 'Email (Opsional)'),
                  ),
                  const SizedBox(height: 14),

                  _label('No. HP${phoneRequired ? ' *' : ' (Opsional)'}'),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: AppColors.textPrimary),
                    validator: phoneRequired ? (v) => v!.isEmpty ? 'No. HP wajib diisi' : null : null,
                    decoration: InputDecoration(hintText: phoneRequired ? '08xxxxxxxxxx' : 'No. HP (Opsional)'),
                  ),
                  const SizedBox(height: 14),

                  _label('Alamat *'),
                  TextFormField(
                    controller: _addressCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: AppColors.textPrimary),
                    validator: (v) => v!.isEmpty ? 'Alamat wajib diisi' : null,
                    decoration: const InputDecoration(hintText: 'Alamat lengkap member...'),
                  ),
                  const SizedBox(height: 14),

                  _label('Foto Profil Member'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.surface,
                        backgroundImage: _imageFile != null
                            ? FileImage(_imageFile!)
                            : (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty)
                                ? NetworkImage(_existingPhotoUrl!) as ImageProvider
                                : null,
                        child: _imageFile == null && (_existingPhotoUrl == null || _existingPhotoUrl!.isEmpty)
                            ? const Icon(Icons.person_rounded, size: 40, color: AppColors.textMuted)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _showPhotoSourceBottomSheet(),
                              icon: const Icon(Icons.camera_alt_rounded, size: 18),
                              label: const Text('Pilih Foto Baru'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.card,
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(color: AppColors.border),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Format JPG/PNG, Maks. 5MB',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text('Simpan Perubahan'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      );
}
