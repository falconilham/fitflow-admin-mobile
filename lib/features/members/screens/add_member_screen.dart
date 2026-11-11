import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/utils/error_handler.dart';

class PartnerMemberData {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController memberIdCtrl = TextEditingController();
  final TextEditingController rfidCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();
  File? imageFile;
  String? base64Image;
  bool generatingId = false;

  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    memberIdCtrl.dispose();
    rfidCtrl.dispose();
    addressCtrl.dispose();
  }

  Map<String, dynamic> toJson() => {
        'name': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        if (memberIdCtrl.text.isNotEmpty) 'memberId': memberIdCtrl.text.trim(),
        if (rfidCtrl.text.isNotEmpty) 'rfidCardUid': rfidCtrl.text.trim(),
        if (addressCtrl.text.isNotEmpty) 'address': addressCtrl.text.trim(),
        if (base64Image != null) 'memberPhoto': base64Image,
      };
}

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
  final _rfidCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  List<MembershipPackage> _packages = [];
  List<Member> _allMembers = [];
  List<Trainer> _trainers = [];
  int? _selectedPkg;
  int? _selectedTrainerId;
  final List<PartnerMemberData> _partners = [];

  bool _loading = false;
  bool _pkgLoading = true;
  bool _generatingId = false;
  GymSettings _settings = const GymSettings();

  File? _imageFile;
  String? _base64Image;
  bool _isSharedPhone = false;
  int? _referenceMemberId;

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
    _rfidCtrl.dispose();
    _addressCtrl.dispose();
    for (final p in _partners) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchData() async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) {
      setState(() => _pkgLoading = false);
      return;
    }
    try {
      final results = await Future.wait([
        ref.read(apiRepositoryProvider).getPackages(gymId),
        ref.read(apiRepositoryProvider).getGymSettings(gymId).catchError((_) => const GymSettings()),
        ref.read(apiRepositoryProvider).getMembers(gymId, limit: 1000).catchError((_) => <Member>[]),
        ref.read(apiRepositoryProvider).getTrainers(gymId).catchError((_) => <Map<String, dynamic>>[]),
      ]);
      setState(() {
        _packages = results[0] as List<MembershipPackage>;
        _settings = results[1] as GymSettings;
        _allMembers = results[2] as List<Member>;
        final trainerData = results[3] as List<Map<String, dynamic>>;
        _trainers = trainerData.map((t) => Trainer.fromJson(t)).toList();
        _pkgLoading = false;
      });
    } catch (_) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal generate ID: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingId = false);
    }
  }

  Future<void> _generatePartnerId(PartnerMemberData partner) async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    setState(() => partner.generatingId = true);
    try {
      final id = await ref.read(apiRepositoryProvider).generateMemberId(gymId);
      partner.memberIdCtrl.text = id;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal generate ID partner: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => partner.generatingId = false);
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

  Future<void> _pickPartnerImage(PartnerMemberData partner, ImageSource source) async {
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
          partner.imageFile = File(pickedFile.path);
          partner.base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil gambar partner: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showPhotoSourceBottomSheet({PartnerMemberData? partner}) {
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
                if (partner != null) {
                  _pickPartnerImage(partner, ImageSource.camera);
                } else {
                  _pickImage(ImageSource.camera);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.accent),
              title: const Text('Galeri', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                if (partner != null) {
                  _pickPartnerImage(partner, ImageSource.gallery);
                } else {
                  _pickImage(ImageSource.gallery);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onPackageSelected(int pkgId) {
    setState(() {
      _selectedPkg = pkgId;
      final pkg = _packages.firstWhere((p) => p.id == pkgId);

      // Adjust dynamic partner slots for group/multi-member packages
      final targetPartners = pkg.isGroupPackage ? pkg.memberCapacity - 1 : 0;
      while (_partners.length < targetPartners) {
        _partners.add(PartnerMemberData());
      }
      while (_partners.length > targetPartners) {
        _partners.removeLast().dispose();
      }

      // Reset trainer selection if package has no PT sessions
      if (!pkg.hasPtSessions) {
        _selectedTrainerId = null;
      }
    });
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

    final pkg = _packages.firstWhere((p) => p.id == _selectedPkg);

    // Validate PT Trainer if package has PT sessions
    if (pkg.hasPtSessions && _selectedTrainerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih Personal Trainer untuk paket sesi PT ini'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Validate partner fields
    for (int i = 0; i < _partners.length; i++) {
      final p = _partners[i];
      if (p.nameCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nama lengkap Partner ${i + 1} wajib diisi'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(apiRepositoryProvider).createMember(gymId, {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        if (_memberIdCtrl.text.isNotEmpty) 'memberId': _memberIdCtrl.text.trim(),
        if (_rfidCtrl.text.isNotEmpty) 'rfidCardUid': _rfidCtrl.text.trim(),
        'packageId': _selectedPkg,
        if (_selectedTrainerId != null) 'selectedTrainerId': _selectedTrainerId,
        if (_base64Image != null) 'memberPhoto': _base64Image,
        'isSharedPhone': _isSharedPhone,
        if (_isSharedPhone && _referenceMemberId != null) 'referenceMemberId': _referenceMemberId,
        if (_partners.isNotEmpty)
          'additionalMembers': _partners.map((p) => p.toJson()).toList(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member berhasil ditambahkan'), backgroundColor: AppColors.success),
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
    final emailRequired = _settings.mandatoryContact == 'email';
    final phoneRequired = _settings.mandatoryContact == 'phone';
    final selectedPkgObj = _selectedPkg != null
        ? _packages.firstWhere((p) => p.id == _selectedPkg, orElse: () => _packages.first)
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tambah Member'),
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
            // ── INFORMASI MEMBER UTAMA ──
            _section('Informasi Member Utama', [
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

              _label('RFID Card UID (Opsional / Gate Access)'),
              TextFormField(
                controller: _rfidCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(hintText: 'Tap kartu RFID atau masukkan UID'),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Checkbox(
                    value: _isSharedPhone,
                    activeColor: AppColors.accent,
                    checkColor: Colors.black,
                    onChanged: (val) {
                      setState(() {
                        _isSharedPhone = val ?? false;
                        if (!_isSharedPhone) {
                          _referenceMemberId = null;
                          _emailCtrl.clear();
                          _phoneCtrl.clear();
                        }
                      });
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'Gunakan Kontak Member Lain (Shared Phone & Email)',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (_isSharedPhone) ...[
                _label('Pilih Member Referensi *'),
                Autocomplete<Member>(
                  displayStringForOption: (Member option) => '${option.name} (${option.phone ?? "No Phone"})',
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return _allMembers;
                    }
                    return _allMembers.where((Member option) {
                      return option.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                          (option.phone ?? '').contains(textEditingValue.text);
                    });
                  },
                  onSelected: (Member selection) {
                    setState(() {
                      _referenceMemberId = selection.id;
                      _emailCtrl.text = selection.email;
                      _phoneCtrl.text = selection.phone ?? '';
                    });
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        color: AppColors.surface,
                        elevation: 4.0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width - 64,
                          height: 200,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final option = options.elementAt(index);
                              return InkWell(
                                onTap: () => onSelected(option),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        option.name,
                                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        option.phone ?? 'No Phone',
                                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                    return TextFormField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Cari nama atau no. HP member...',
                      ),
                      validator: (v) => _isSharedPhone && _referenceMemberId == null ? 'Pilih member referensi' : null,
                    );
                  },
                ),
                const SizedBox(height: 14),
              ],

              _label('Email${emailRequired ? ' *' : ' (Opsional)'}'),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppColors.textPrimary),
                readOnly: _isSharedPhone,
                validator: emailRequired && !_isSharedPhone ? (v) => v!.isEmpty ? 'Email wajib diisi' : null : null,
                decoration: InputDecoration(hintText: emailRequired ? 'john@email.com' : 'Email (Opsional)'),
              ),
              const SizedBox(height: 14),

              _label('No. HP${phoneRequired ? ' *' : ' (Opsional)'}'),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: AppColors.textPrimary),
                readOnly: _isSharedPhone,
                validator: phoneRequired && !_isSharedPhone ? (v) => v!.isEmpty ? 'No. HP wajib diisi' : null : null,
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
                    backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                    child: _imageFile == null
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
                          label: const Text('Pilih Foto'),
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
            ]),
            const SizedBox(height: 16),

            // ── PILIH PAKET MEMBERSHIP ──
            _section('Pilih Paket Membership *', [
              if (_pkgLoading)
                const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
              else if (_packages.isEmpty)
                const Text('Belum ada paket di gym ini', style: TextStyle(color: AppColors.textMuted))
              else
                ..._packages.map((p) => _PkgTile(
                      pkg: p,
                      selected: _selectedPkg == p.id,
                      onTap: () => _onPackageSelected(p.id),
                    )),
            ]),
            const SizedBox(height: 16),

            // ── PEMILIHAN PERSONAL TRAINER (JIKA PAKET SESI PT / BONUS PT) ──
            if (selectedPkgObj != null && selectedPkgObj.hasPtSessions) ...[
              _section('Pilih Personal Trainer (Sesi PT) *', [
                Row(
                  children: [
                    const Icon(LucideIcons.dumbbell, size: 16, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedPkgObj.type == 'PT'
                            ? 'Paket ini mencakup ${selectedPkgObj.totalSessions ?? 1} Sesi Personal Trainer'
                            : 'Paket ini memberikan Bonus ${selectedPkgObj.bonusPtSessions} Sesi PT',
                        style: const TextStyle(color: AppColors.accent, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _label('Personal Trainer yang Ditugaskan *'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedTrainerId,
                      dropdownColor: AppColors.surface,
                      isExpanded: true,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      hint: const Text('Pilih Trainer...', style: TextStyle(color: AppColors.textMuted)),
                      items: _trainers.map((t) {
                        return DropdownMenuItem<int>(
                          value: t.id,
                          child: Text(
                            '${t.name}${t.specialty != null && t.specialty!.isNotEmpty ? " (${t.specialty})" : ""}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedTrainerId = val);
                      },
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
            ],

            // ── DATA MULTI-MEMBER / PARTNER (JIKA KAPASITAS PAKET > 1) ──
            if (_partners.isNotEmpty) ...[
              ...List.generate(_partners.length, (idx) {
                final partner = _partners[idx];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _section('Partner / Sub Member #${idx + 1}', [
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.accent.withAlpha(60)),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.users, size: 16, color: AppColors.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Anggota ke-${idx + 2} dari paket ${selectedPkgObj?.name ?? "Duo/Group"}',
                              style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),

                    _label('Member ID Partner (Opsional)'),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: partner.memberIdCtrl,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: const InputDecoration(hintText: 'e.g. MEM-002'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: partner.generatingId ? null : () => _generatePartnerId(partner),
                          child: partner.generatingId
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

                    _label('Nama Lengkap Partner *'),
                    TextFormField(
                      controller: partner.nameCtrl,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(hintText: 'Nama lengkap partner'),
                    ),
                    const SizedBox(height: 14),

                    _label('No. WhatsApp / HP Partner${phoneRequired ? ' *' : ' (Opsional)'}'),
                    TextFormField(
                      controller: partner.phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(hintText: '08xxxxxxxxxx'),
                    ),
                    const SizedBox(height: 14),

                    _label('Email Partner${emailRequired ? ' *' : ' (Opsional)'}'),
                    TextFormField(
                      controller: partner.emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(hintText: 'partner@email.com'),
                    ),
                    const SizedBox(height: 14),

                    _label('RFID Card UID (Opsional / Gate Access)'),
                    TextFormField(
                      controller: partner.rfidCtrl,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(hintText: 'UID Kartu RFID Partner'),
                    ),
                    const SizedBox(height: 14),

                    _label('Alamat Partner (Opsional)'),
                    TextFormField(
                      controller: partner.addressCtrl,
                      maxLines: 2,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(hintText: 'Alamat partner...'),
                    ),
                    const SizedBox(height: 14),

                    _label('Foto Profil Partner'),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.surface,
                          backgroundImage: partner.imageFile != null ? FileImage(partner.imageFile!) : null,
                          child: partner.imageFile == null
                              ? const Icon(Icons.person_rounded, size: 36, color: AppColors.textMuted)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showPhotoSourceBottomSheet(partner: partner),
                            icon: const Icon(Icons.camera_alt_rounded, size: 18),
                            label: const Text('Pilih Foto Partner'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.card,
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ]),
                );
              }),
            ],

            const SizedBox(height: 8),

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
                    : const Text('Simpan Member'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      );
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
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withAlpha(25) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.accent.withAlpha(127) : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          pkg.name,
                          style: TextStyle(
                            color: selected ? AppColors.accent : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (pkg.isGroupPackage) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha(40),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue.withAlpha(100)),
                          ),
                          child: Text(
                            '${pkg.memberCapacity} Orang',
                            style: const TextStyle(color: Colors.blue, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      if (pkg.hasPtSessions) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.withAlpha(40),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.purple.withAlpha(100)),
                          ),
                          child: Text(
                            pkg.type == 'PT'
                                ? '${pkg.totalSessions ?? 1} Sesi PT'
                                : '+${pkg.bonusPtSessions} Bonus PT',
                            style: const TextStyle(color: Colors.purpleAccent, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pkg.type == 'SESSION'
                        ? '${pkg.totalSessions ?? 0} Sesi Kunjungan'
                        : '${pkg.durationMonths} bulan',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Rp ${pkg.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
              style: TextStyle(
                color: selected ? AppColors.accent : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
