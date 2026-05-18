import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/drawer_menu_button.dart';
import '../../../shared/utils/error_handler.dart';
import '../../../shared/utils/format.dart';

final gymSettingsProvider = FutureProvider.autoDispose<GymSettings>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) throw Exception('Gym context required');
  return ref.read(apiRepositoryProvider).getGymSettings(gymId);
});

final membershipPackagesProvider = FutureProvider.autoDispose<List<MembershipPackage>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) throw Exception('Gym context required');
  return ref.read(apiRepositoryProvider).getPackages(gymId);
});

class GymSettingsScreen extends ConsumerStatefulWidget {
  const GymSettingsScreen({super.key});

  @override
  ConsumerState<GymSettingsScreen> createState() => _GymSettingsScreenState();
}

class _GymSettingsScreenState extends ConsumerState<GymSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _regFeeCtrl = TextEditingController();
  final _reRegFeeCtrl = TextEditingController();
  final _gracePeriodCtrl = TextEditingController();
  final _prefixCtrl = TextEditingController();
  final _taxRateCtrl = TextEditingController();

  String _primaryColor = '#bef264';
  String _secondaryColor = '#1a1a1a';
  String _mandatoryContact = 'email';
  bool _requireMemberId = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _regFeeCtrl.dispose();
    _reRegFeeCtrl.dispose();
    _gracePeriodCtrl.dispose();
    _prefixCtrl.dispose();
    _taxRateCtrl.dispose();
    super.dispose();
  }

  void _initFields(GymSettings settings) {
    _nameCtrl.text = settings.name;
    _addressCtrl.text = settings.address ?? '';
    _phoneCtrl.text = settings.phone ?? '';
    _emailCtrl.text = settings.email ?? '';
    _regFeeCtrl.text = settings.registrationFee.toString();
    _reRegFeeCtrl.text = settings.reRegistrationFee.toString();
    _gracePeriodCtrl.text = settings.inactivityGracePeriod.toString();
    _prefixCtrl.text = settings.memberIdPrefix ?? '';
    _taxRateCtrl.text = settings.taxRate.toString();
    _primaryColor = settings.primaryColor;
    _secondaryColor = settings.secondaryColor;
    _mandatoryContact = settings.mandatoryContact;
    _requireMemberId = settings.requireMemberId;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;

    setState(() => _saving = true);
    try {
      final data = {
        'name': _nameCtrl.text,
        'address': _addressCtrl.text,
        'phone': _phoneCtrl.text,
        'email': _emailCtrl.text,
        'registrationFee': int.tryParse(_regFeeCtrl.text) ?? 0,
        'reRegistrationFee': int.tryParse(_reRegFeeCtrl.text) ?? 0,
        'inactivityGracePeriod': int.tryParse(_gracePeriodCtrl.text) ?? 3,
        'memberIdPrefix': _prefixCtrl.text,
        'taxRate': double.tryParse(_taxRateCtrl.text) ?? 0.0,
        'primaryColor': _primaryColor,
        'secondaryColor': _secondaryColor,
        'mandatoryContact': _mandatoryContact,
        'requireMemberId': _requireMemberId,
      };

      await ref.read(apiRepositoryProvider).updateGymSettings(gymId, data);
      ref.invalidate(gymSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${ErrorHandler.parse(e)}'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(gymSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Gym Settings'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(text: 'General'),
            Tab(text: 'Contact'),
            Tab(text: 'Membership'),
            Tab(text: 'Packages'),
          ],
        ),
        actions: [
          if (_tabController.index != 3) // Hide save button for packages tab
            if (!_saving)
              IconButton(
                icon: const Icon(Icons.save_rounded),
                onPressed: _save,
              )
            else
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                ),
              ),
        ],
      ),
      body: settingsAsync.when(
        data: (settings) {
          if (_nameCtrl.text.isEmpty && settings.name.isNotEmpty) {
            _initFields(settings);
          }
          return Form(
            key: _formKey,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGeneralTab(),
                _buildContactTab(),
                _buildMembershipTab(),
                _buildPackagesTab(),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(child: Text('Error: ${ErrorHandler.parse(e)}', style: const TextStyle(color: AppColors.error))),
      ),
      floatingActionButton: _tabController.index == 3
          ? FloatingActionButton(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              onPressed: () => _showAddEditPackageDialog(),
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader('Branding'),
        const SizedBox(height: 16),
        _buildTextField('Gym Name', _nameCtrl, Icons.business_rounded),
        const SizedBox(height: 20),
        _buildColorPicker('Primary Color', _primaryColor, (c) => setState(() => _primaryColor = c)),
        const SizedBox(height: 16),
        _buildColorPicker('Secondary Color', _secondaryColor, (c) => setState(() => _secondaryColor = c)),
        const SizedBox(height: 32),
        _buildSectionHeader('Finances'),
        const SizedBox(height: 16),
        _buildTextField('Tax Rate (%)', _taxRateCtrl, Icons.percent_rounded, keyboardType: TextInputType.number),
      ],
    );
  }

  Widget _buildContactTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader('Contact Information'),
        const SizedBox(height: 16),
        _buildTextField('Address', _addressCtrl, Icons.location_on_rounded, maxLines: 3),
        const SizedBox(height: 16),
        _buildTextField('Phone', _phoneCtrl, Icons.phone_rounded, keyboardType: TextInputType.phone),
        const SizedBox(height: 16),
        _buildTextField('Email', _emailCtrl, Icons.email_rounded, keyboardType: TextInputType.emailAddress),
      ],
    );
  }

  Widget _buildMembershipTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader('Rules & Fees'),
        const SizedBox(height: 16),
        _buildTextField('Registration Fee', _regFeeCtrl, Icons.payments_rounded, keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        _buildTextField('Re-Registration Fee', _reRegFeeCtrl, Icons.refresh_rounded, keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        _buildTextField('Inactivity Grace Period (Months)', _gracePeriodCtrl, Icons.timer_rounded, keyboardType: TextInputType.number),
        const SizedBox(height: 32),
        _buildSectionHeader('Identification'),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Require Member ID', style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
          subtitle: const Text('Ensure every member has a unique ID', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          value: _requireMemberId,
          activeThumbColor: AppColors.accent,
          onChanged: (v) => setState(() => _requireMemberId = v),
        ),
        if (_requireMemberId) ...[
          const SizedBox(height: 8),
          _buildTextField('Member ID Prefix', _prefixCtrl, Icons.label_important_rounded),
        ],
        const SizedBox(height: 16),
        const Text('Mandatory Contact Info', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _mandatoryContact,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.contact_mail_rounded, color: AppColors.textMuted),
          ),
          items: const [
            DropdownMenuItem(value: 'none', child: Text('None')),
            DropdownMenuItem(value: 'email', child: Text('Email')),
            DropdownMenuItem(value: 'phone', child: Text('Phone')),
            DropdownMenuItem(value: 'both', child: Text('Both')),
          ],
          onChanged: (v) => setState(() => _mandatoryContact = v!),
        ),
      ],
    );
  }

  Widget _buildPackagesTab() {
    final packagesAsync = ref.watch(membershipPackagesProvider);
    return packagesAsync.when(
      data: (packages) {
        if (packages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.card_membership_rounded, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                const Text(
                  'Belum ada paket membership',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mulai dengan menambahkan paket baru.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _showAddEditPackageDialog(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Tambah Paket'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(membershipPackagesProvider),
          color: AppColors.accent,
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: packages.length,
            itemBuilder: (context, index) {
              final pkg = packages[index];
              return _buildPackageCard(pkg);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: ${ErrorHandler.parse(e)}', style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(membershipPackagesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageCard(MembershipPackage pkg) {
    String typeText = 'Period-based';
    String durationText = '${pkg.durationMonths} Bulan';
    if (pkg.type == 'WEEK') {
      typeText = 'Weekly';
      durationText = '${pkg.durationMonths} Minggu';
    } else if (pkg.type == 'SESSION') {
      typeText = 'Session-based';
      durationText = '${pkg.totalSessions ?? 0} Sesi (${pkg.sessionDuration ?? 0} Menit)';
    }

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            pkg.name,
            style: TextStyle(
              color: pkg.isActive ? AppColors.textPrimary : AppColors.textMuted,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              decoration: pkg.isActive ? null : TextDecoration.lineThrough,
            ),
          ),
          subtitle: Row(
            children: [
              Text(
                formatCurrency(pkg.price.toDouble()),
                style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  typeText,
                  style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              if (!pkg.isActive) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Non-aktif',
                    style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: AppColors.border, height: 20),
                  _buildDetailRow('Tipe Paket', typeText),
                  _buildDetailRow('Durasi / Kuota', durationText),
                  _buildDetailRow('Biaya Pendaftaran', pkg.hasRegistrationFee ? 'Dikenakan' : 'Gratis'),
                  if (pkg.description != null && pkg.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Deskripsi:', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(pkg.description!, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: AppColors.textMuted),
                        onPressed: () => _showAddEditPackageDialog(pkg),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_rounded, color: AppColors.error),
                        onPressed: () => _confirmDeletePackage(pkg),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showAddEditPackageDialog([MembershipPackage? pkg]) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: pkg?.name);
    final priceCtrl = TextEditingController(text: pkg?.price.toString());
    final descCtrl = TextEditingController(text: pkg?.description);
    final durationMonthsCtrl = TextEditingController(text: pkg?.durationMonths.toString() ?? '1');
    final totalSessionsCtrl = TextEditingController(text: pkg?.totalSessions?.toString() ?? '10');
    final sessionDurationCtrl = TextEditingController(text: pkg?.sessionDuration?.toString() ?? '60');

    String type = pkg?.type ?? 'PERIOD';
    bool hasRegFee = pkg?.hasRegistrationFee ?? true;
    bool isActive = pkg?.isActive ?? true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                pkg == null ? 'Tambah Paket Baru' : 'Edit Paket Membership',
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nama Paket
                      TextFormField(
                        controller: nameCtrl,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Nama Paket *',
                          prefixIcon: Icon(Icons.label_rounded, color: AppColors.textMuted),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Nama harus diisi' : null,
                      ),
                      const SizedBox(height: 16),

                      // Tipe Paket Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        dropdownColor: AppColors.surface,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Tipe Paket *',
                          prefixIcon: Icon(Icons.category_rounded, color: AppColors.textMuted),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'PERIOD', child: Text('Period-based (Bulanan)')),
                          DropdownMenuItem(value: 'WEEK', child: Text('Weekly-based (Mingguan)')),
                          DropdownMenuItem(value: 'SESSION', child: Text('Session-based (Kuota)')),
                        ],
                        onChanged: (v) {
                          setDialogState(() {
                            type = v!;
                            // Reset duration if type changes
                            if (type == 'WEEK') {
                              durationMonthsCtrl.text = '1';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Harga
                      TextFormField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Harga Paket * (Rp)',
                          prefixIcon: Icon(Icons.payments_rounded, color: AppColors.textMuted),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Harga harus diisi' : null,
                      ),
                      const SizedBox(height: 16),

                      // Conditionally show inputs based on type
                      if (type == 'PERIOD') ...[
                        TextFormField(
                          controller: durationMonthsCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Durasi (Bulan) *',
                            prefixIcon: Icon(Icons.calendar_month_rounded, color: AppColors.textMuted),
                          ),
                          validator: (v) => (v == null || int.tryParse(v) == null || int.parse(v) <= 0) ? 'Durasi tidak valid' : null,
                        ),
                        const SizedBox(height: 16),
                      ] else if (type == 'WEEK') ...[
                        TextFormField(
                          controller: durationMonthsCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Durasi (Minggu) * (Maks 3)',
                            prefixIcon: Icon(Icons.date_range_rounded, color: AppColors.textMuted),
                          ),
                          validator: (v) {
                            final val = int.tryParse(v ?? '');
                            if (val == null || val < 1 || val > 3) {
                              return 'Harus antara 1 s/d 3 minggu';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ] else if (type == 'SESSION') ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: totalSessionsCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: AppColors.textPrimary),
                                decoration: const InputDecoration(
                                  labelText: 'Total Sesi *',
                                  prefixIcon: Icon(Icons.pin_rounded, color: AppColors.textMuted),
                                ),
                                validator: (v) => (v == null || int.tryParse(v) == null || int.parse(v) <= 0) ? 'Harus > 0' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: sessionDurationCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: AppColors.textPrimary),
                                decoration: const InputDecoration(
                                  labelText: 'Durasi (Menit) *',
                                  prefixIcon: Icon(Icons.timer_rounded, color: AppColors.textMuted),
                                ),
                                validator: (v) => (v == null || int.tryParse(v) == null || int.parse(v) <= 0) ? 'Harus > 0' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Deskripsi
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 2,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Deskripsi Paket',
                          prefixIcon: Icon(Icons.description_rounded, color: AppColors.textMuted),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Biaya Registrasi Switch
                      SwitchListTile(
                        title: const Text('Kenakan Biaya Registrasi', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                        subtitle: const Text('Terapkan rules biaya pendaftaran', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        value: hasRegFee,
                        activeThumbColor: AppColors.accent,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setDialogState(() => hasRegFee = v),
                      ),

                      if (pkg != null) ...[
                        // Status Aktif Switch (Hanya saat edit)
                        SwitchListTile(
                          title: const Text('Status Paket Aktif', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                          subtitle: const Text('Non-aktifkan agar tidak bisa dibeli lagi', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          value: isActive,
                          activeThumbColor: AppColors.accent,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) => setDialogState(() => isActive = v),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    
                    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
                    if (gymId == null) return;

                    final Map<String, dynamic> data = {
                      'name': nameCtrl.text,
                      'type': type,
                      'price': int.parse(priceCtrl.text),
                      'description': descCtrl.text,
                      'hasRegistrationFee': hasRegFee,
                      'durationMonths': type == 'SESSION' ? null : int.parse(durationMonthsCtrl.text),
                      'totalSessions': type == 'SESSION' ? int.parse(totalSessionsCtrl.text) : null,
                      'sessionDuration': type == 'SESSION' ? int.parse(sessionDurationCtrl.text) : null,
                    };

                    if (pkg != null) {
                      data['isActive'] = isActive;
                    }

                    try {
                      if (pkg == null) {
                        await ref.read(apiRepositoryProvider).createPackage(gymId, data);
                      } else {
                        await ref.read(apiRepositoryProvider).updatePackage(pkg.id, data);
                      }
                      ref.invalidate(membershipPackagesProvider);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(pkg == null ? 'Paket berhasil ditambahkan!' : 'Paket berhasil diubah!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: ${ErrorHandler.parse(e)}'), backgroundColor: AppColors.error),
                        );
                      }
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeletePackage(MembershipPackage pkg) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Hapus Paket?', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          content: Text('Apakah Anda yakin ingin menghapus paket "${pkg.name}"? Tindakan ini tidak dapat dibatalkan jika paket sudah digunakan.', style: const TextStyle(color: AppColors.textMuted)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                try {
                  await ref.read(apiRepositoryProvider).deletePackage(pkg.id);
                  ref.invalidate(membershipPackagesProvider);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Paket berhasil dihapus!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${ErrorHandler.parse(e)}'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, IconData icon, {TextInputType? keyboardType, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textMuted),
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Field required' : null,
    );
  }

  Widget _buildColorPicker(String label, String currentColor, Function(String) onColorChanged) {
    Color color = Color(int.parse(currentColor.replaceFirst('#', '0xFF')));
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
      trailing: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
      ),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Pick $label'),
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: color,
                onColorChanged: (newColor) {
                  onColorChanged('#${newColor.toARGB32().toRadixString(16).substring(2)}');
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
            ],
          ),
        );
      },
    );
  }
}
