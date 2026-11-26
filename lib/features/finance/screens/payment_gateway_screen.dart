import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/utils/error_handler.dart';
import '../../../shared/widgets/drawer_menu_button.dart';

class PaymentGatewayScreen extends ConsumerStatefulWidget {
  const PaymentGatewayScreen({super.key});

  @override
  ConsumerState<PaymentGatewayScreen> createState() =>
      _PaymentGatewayScreenState();
}

class _PaymentGatewayScreenState extends ConsumerState<PaymentGatewayScreen> {
  final _serverKeyCtrl = TextEditingController();
  final _clientKeyCtrl = TextEditingController();
  final _merchantIdCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  String? _error;

  String _provider = 'midtrans';
  bool _isEnabled = false;
  bool _isProduction = true;
  bool _enableAutoConfirmation = true;
  String? _testMessage;
  bool? _testValid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _serverKeyCtrl.dispose();
    _clientKeyCtrl.dispose();
    _merchantIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiRepositoryProvider).getPaymentSettings(gymId);
      final s = res['setting'] is Map
          ? Map<String, dynamic>.from(res['setting'] as Map)
          : const <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _provider = s['provider'] as String? ?? 'midtrans';
        _isEnabled = s['isEnabled'] as bool? ?? false;
        _isProduction = s['isProduction'] as bool? ?? true;
        _enableAutoConfirmation = s['enableAutoConfirmation'] as bool? ?? true;
        _serverKeyCtrl.text = s['serverKey'] as String? ?? '';
        _clientKeyCtrl.text = s['clientKey'] as String? ?? '';
        _merchantIdCtrl.text = s['merchantId'] as String? ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.parse(e);
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiRepositoryProvider).updatePaymentSettings(gymId, {
        'provider': _provider,
        'isEnabled': _isEnabled,
        'isProduction': _isProduction,
        'enableAutoConfirmation': _enableAutoConfirmation,
        'serverKey': _serverKeyCtrl.text.trim(),
        'clientKey': _clientKeyCtrl.text.trim(),
        'merchantId': _merchantIdCtrl.text.trim(),
      });
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengaturan Payment Gateway disimpan')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.parse(e)), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _testConnection() async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    setState(() {
      _testing = true;
      _testMessage = null;
    });
    try {
      final res = await ref.read(apiRepositoryProvider).testPaymentConnection(
        gymId,
        {
          'provider': _provider,
          'serverKey': _serverKeyCtrl.text.trim(),
          'isProduction': _isProduction,
        },
      );
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testValid = res['valid'] as bool? ?? false;
        _testMessage = res['message'] as String? ?? 'Tes selesai';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testValid = false;
        _testMessage = ErrorHandler.parse(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: Text(l10n.menuPaymentGateway),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _provider,
                            dropdownColor: AppColors.surface,
                            decoration: const InputDecoration(labelText: 'Provider'),
                            items: const [
                              DropdownMenuItem(
                                value: 'midtrans',
                                child: Text('Midtrans'),
                              ),
                              DropdownMenuItem(
                                value: 'xendit',
                                child: Text('Xendit'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _provider = v);
                            },
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            value: _isEnabled,
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: AppColors.accent,
                            title: const Text('Aktifkan Pembayaran Online'),
                            onChanged: (v) => setState(() => _isEnabled = v),
                          ),
                          SwitchListTile(
                            value: _isProduction,
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: AppColors.accent,
                            title: const Text('Mode Production (Live)'),
                            onChanged: (v) => setState(() => _isProduction = v),
                          ),
                          SwitchListTile(
                            value: _enableAutoConfirmation,
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: AppColors.accent,
                            title: const Text('Konfirmasi Otomatis Webhook'),
                            onChanged: (v) =>
                                setState(() => _enableAutoConfirmation = v),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _merchantIdCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Merchant ID'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _clientKeyCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Client Key'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _serverKeyCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Server / Secret Key',
                            ),
                          ),
                          if (_testMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _testMessage!,
                              style: GoogleFonts.figtree(
                                color: _testValid == true
                                    ? AppColors.success
                                    : AppColors.error,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _testing ? null : _testConnection,
                                  icon: const Icon(LucideIcons.plug, size: 15),
                                  label: Text(_testing ? 'Menguji...' : 'Tes Koneksi'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _saving ? null : _save,
                                  child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
