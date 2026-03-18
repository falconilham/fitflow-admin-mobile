import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/drawer_menu_button.dart';

final gymSettingsProvider = FutureProvider.autoDispose<GymSettings>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) throw Exception('Gym context required');
  return ref.read(apiRepositoryProvider).getGymSettings(gymId);
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
    _tabController = TabController(length: 3, vsync: this);
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
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
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
          ],
        ),
        actions: [
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
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
      ),
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
