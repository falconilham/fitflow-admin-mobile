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

  // New features: Change Password & Extend Membership
  bool _changePasswordMode = false;
  final _passwordCtrl = TextEditingController();

  bool _extendMode = false;
  int? _selectedPackageId;
  String _paymentMethod = 'Cash';
  List<MembershipPackage> _packages = [];

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
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    try {
      final futures = [
        ref.read(apiRepositoryProvider).getMemberDetail(widget.memberId),
        if (gymId != null) ref.read(apiRepositoryProvider).getGymSettings(gymId).catchError((_) => const GymSettings()),
        if (gymId != null) ref.read(apiRepositoryProvider).getPackages(gymId).catchError((_) => <MembershipPackage>[]),
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
      
      if (results.length > 2) {
        _packages = results[2] as List<MembershipPackage>;
        if (m.packageId != null && _packages.any((p) => p.id == m.packageId)) {
          _selectedPackageId = m.packageId;
        } else if (_packages.isNotEmpty) {
          _selectedPackageId = _packages.first.id;
        }
      }
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
    if (_changePasswordMode && _passwordCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password baru wajib diisi'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (_extendMode && _selectedPackageId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih paket untuk perpanjangan'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final selectedPkg = _selectedPackageId != null
          ? _packages.firstWhere((p) => p.id == _selectedPackageId, orElse: () => _packages.first)
          : null;

      await ref.read(apiRepositoryProvider).updateMember(widget.memberId, {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        if (_memberIdCtrl.text.isNotEmpty) 'memberId': _memberIdCtrl.text.trim(),
        if (_base64Image != null) 'memberPhoto': _base64Image,
        'password': _changePasswordMode ? _passwordCtrl.text.trim() : null,
        'extendDuration': _extendMode && selectedPkg != null ? selectedPkg.durationMonths : null,
        'paymentMethod': _extendMode ? _paymentMethod : null,
        'packageId': _extendMode ? _selectedPackageId : null,
        'pricePaid': _extendMode && selectedPkg != null ? selectedPkg.price : null,
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
            
            const SizedBox(height: 16),
            // Change Password Card
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'GANTI PASSWORD',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Switch(
                        value: _changePasswordMode,
                        activeThumbColor: AppColors.accent,
                        onChanged: (val) {
                          setState(() {
                            _changePasswordMode = val;
                          });
                        },
                      ),
                    ],
                  ),
                  if (_changePasswordMode) ...[
                    const SizedBox(height: 10),
                    _label('Password Baru *'),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Password baru minimal 6 karakter',
                      ),
                      validator: (v) {
                        if (_changePasswordMode && (v == null || v.isEmpty)) {
                          return 'Password baru wajib diisi';
                        }
                        if (_changePasswordMode && v!.length < 6) {
                          return 'Password minimal 6 karakter';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),
            // Extend Membership Card
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'PERPANJANG MEMBERSHIP',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Switch(
                        value: _extendMode,
                        activeThumbColor: AppColors.accent,
                        onChanged: (val) {
                          setState(() {
                            _extendMode = val;
                          });
                        },
                      ),
                    ],
                  ),
                  if (_extendMode) ...[
                    const SizedBox(height: 14),
                    _label('Pilih Paket Membership *'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedPackageId,
                          dropdownColor: AppColors.surface,
                          isExpanded: true,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          hint: const Text('Pilih Paket', style: TextStyle(color: AppColors.textMuted)),
                          items: _packages.map((pkg) {
                            return DropdownMenuItem<int>(
                              value: pkg.id,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      pkg.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    'Rp ${pkg.price.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]}.")}',
                                    style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedPackageId = val;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _label('Metode Pembayaran *'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _paymentMethod,
                          dropdownColor: AppColors.surface,
                          isExpanded: true,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          items: const [
                            DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                            DropdownMenuItem(value: 'Transfer', child: Text('Transfer')),
                            DropdownMenuItem(value: 'QR', child: Text('QR Code')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _paymentMethod = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
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
