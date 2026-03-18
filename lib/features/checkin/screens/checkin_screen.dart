import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/drawer_menu_button.dart';

class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key});
  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  final _searchCtrl = TextEditingController();
  final _cameraCtrl = MobileScannerController();
  String _tab = 'manual'; // 'manual' | 'scan'
  List<Member> _members = [];
  bool _searching = false;
  bool _isScanning = false;
  Map<int, bool> _checkingIn = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    _cameraCtrl.stop();
    _cameraCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_searchCtrl.text.trim().isEmpty) return;
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    setState(() => _searching = true);
    try {
      final rows = await ref.read(apiRepositoryProvider).getMembers(gymId, search: _searchCtrl.text.trim(), limit: 20);
      setState(() => _members = rows);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mencari member: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _checkInManual(Member member) async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null || member.userId == null) return;
    setState(() => _checkingIn[member.id] = true);
    try {
      final res = await ref.read(apiRepositoryProvider).checkInByQr(gymId, member.userId!, member.id);
      
      // Defensive parsing of response
      final resStatus = res['access']?.toString() ?? res['status']?.toString() ?? '';
      final isGranted = resStatus == 'granted' || resStatus == 'success';
      final isCheckout = res['type']?.toString() == 'checkout';
      
      final memberMap = res['member'] as Map? ?? (res['data'] as Map?)?['member'] as Map?;
      final name = memberMap?['name']?.toString() ?? member.name;
      final message = res['message']?.toString() ?? res['status']?.toString() ?? '';
      
      if (mounted) _showResult(isGranted, isCheckout, name, message);
    } catch (e) {
      final errMsg = e.toString().contains('response') ? 'Check-in gagal' : e.toString();
      if (mounted) _showResult(false, false, member.name, errMsg);
    } finally {
      if (mounted) setState(() => _checkingIn.remove(member.id));
    }
  }

  Future<void> _handleQr(BarcodeCapture capture) async {
    if (_isScanning) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    setState(() => _isScanning = true);
    _cameraCtrl.stop(); // Stop scanning immediately to save resources and prevent multiple scans
    try {
      // QR format: JSON {"userId": N, "gymId": N, "membershipId": N}
      final parsed = _parseQr(raw);
      if (parsed == null) { _showResult(false, false, '', 'Format QR tidak valid'); return; }
      final res = await ref.read(apiRepositoryProvider).checkInByQr(
          parsed['gymId']!, parsed['userId']!, parsed['membershipId']!);
          
      // Defensive parsing of response
      final resStatus = res['access']?.toString() ?? res['status']?.toString() ?? '';
      final isGranted = resStatus == 'granted' || resStatus == 'success';
      final isCheckout = res['type']?.toString() == 'checkout';
      
      final memberMap = res['member'] as Map? ?? (res['data'] as Map?)?['member'] as Map?;
      final name = memberMap?['name']?.toString() ?? '';
      final message = res['message']?.toString() ?? res['status']?.toString() ?? '';
      
      if (mounted) _showResult(isGranted, isCheckout, name, message);
    } catch (e) {
      if (mounted) _showResult(false, false, '', e.toString());
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Map<String, int>? _parseQr(String raw) {
    try {
      // Try JSON first
      final decoded = raw.replaceAll("'", '"');
      final Map<String, dynamic> json = Map<String, dynamic>.from(
        RegExp(r'"(\w+)":\s*(\d+)').allMatches(decoded).fold(<String, dynamic>{},
            (map, m) => map..['${m.group(1)}'] = int.parse(m.group(2)!)));
      if (json.containsKey('userId') && json.containsKey('gymId') && json.containsKey('membershipId')) {
        return {'userId': json['userId'] as int, 'gymId': json['gymId'] as int, 'membershipId': json['membershipId'] as int};
      }
      // Fallback: userId:membershipId
      final parts = raw.split(':');
      if (parts.length == 2) {
        final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
        if (gymId != null) return {'userId': int.parse(parts[0]), 'gymId': gymId, 'membershipId': int.parse(parts[1])};
      }
    } catch (_) {}
    return null;
  }

  void _showResult(bool granted, bool checkout, String name, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          granted ? (checkout ? '✅ Check-out Berhasil' : '✅ Check-in Berhasil') : '❌ Ditolak',
          style: TextStyle(color: granted ? AppColors.success : AppColors.error),
        ),
        content: Text('$name: $message', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (_tab == 'scan') _cameraCtrl.start(); // Restart camera when closing dialog IF still in scan tab
            },
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Check-In', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SafeArea(child: Column(children: [
        // Tab bar
        Container(
          color: AppColors.surface,
          child: Row(children: [
            _TabBtn(label: '🔍 Manual', active: _tab == 'manual', onTap: () {
              if (_tab == 'manual') return;
              setState(() => _tab = 'manual');
              _cameraCtrl.stop();
            }),
            _TabBtn(label: '📷 Scan QR', active: _tab == 'scan', onTap: () {
              if (_tab == 'scan') return;
              setState(() => _tab = 'scan');
              _cameraCtrl.start();
            }),
          ]),
        ),

        if (_tab == 'manual') Expanded(child: _ManualTab(
          searchCtrl: _searchCtrl, members: _members, searching: _searching,
          checkingIn: _checkingIn, onSearch: _search, onCheckIn: _checkInManual,
        ))
        else Expanded(child: _ScanTab(controller: _cameraCtrl, onDetect: _handleQr, isScanning: _isScanning)),
      ])),
    );
  }
}

// ── Tab bar button ──────────────────────────────────────────────────────────

class _TabBtn extends StatelessWidget {
  const _TabBtn({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? AppColors.accent : Colors.transparent, width: 2))),
      child: Center(child: Text(label, style: TextStyle(color: active ? AppColors.accent : AppColors.textMuted, fontWeight: FontWeight.w600))),
    )));
  }
}

// ── Manual search tab ────────────────────────────────────────────────────────

class _ManualTab extends StatelessWidget {
  const _ManualTab({required this.searchCtrl, required this.members, required this.searching,
      required this.checkingIn, required this.onSearch, required this.onCheckIn});
  final TextEditingController searchCtrl;
  final List<Member> members;
  final bool searching;
  final Map<int, bool> checkingIn;
  final VoidCallback onSearch;
  final Future<void> Function(Member) onCheckIn;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(child: TextField(
            controller: searchCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: 'Cari nama atau Member ID...', prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted)),
            onSubmitted: (_) => onSearch(),
          )),
          const SizedBox(width: 10),
          ElevatedButton(onPressed: onSearch, child: const Text('Cari')),
        ]),
      ),
      Expanded(child: searching
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
          : members.isEmpty
              ? Center(child: Text(searchCtrl.text.isNotEmpty ? 'Member tidak ditemukan' : 'Cari member untuk check-in',
                  style: const TextStyle(color: AppColors.textMuted)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: members.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final m = members[i];
                    final isExpired = m.status.toLowerCase() != 'active';
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isExpired ? const Color(0xFF1A0A0A) : AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isExpired ? AppColors.error.withAlpha(76) : AppColors.border),
                      ),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(m.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                          if (m.memberId != null) Text('ID: ${m.memberId}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isExpired ? AppColors.error : AppColors.success).withAlpha(38),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(m.status, style: TextStyle(color: isExpired ? AppColors.error : AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ])),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isExpired ? AppColors.surface : AppColors.accent,
                            foregroundColor: isExpired ? AppColors.textMuted : Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          onPressed: checkingIn[m.id] == true ? null : () => onCheckIn(m),
                          child: checkingIn[m.id] == true
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Text('Check-in', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ]),
                    );
                  }),
      ),
    ]);
  }
}

// ── QR Scan tab ──────────────────────────────────────────────────────────────

class _ScanTab extends StatelessWidget {
  const _ScanTab({required this.controller, required this.onDetect, required this.isScanning});
  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      MobileScanner(controller: controller, onDetect: onDetect),
      // Dark overlay with scan box
      ColorFiltered(
        colorFilter: ColorFilter.mode(Colors.black.withAlpha(127), BlendMode.srcOut),
        child: Stack(children: [
          Container(decoration: const BoxDecoration(color: Colors.black, backgroundBlendMode: BlendMode.dstOut)),
          Center(child: Container(width: 250, height: 250, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)))),
        ]),
      ),
      Positioned.fill(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(height: 270),
        Text('Arahkan QR Code ke dalam kotak', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        if (isScanning) ...[const SizedBox(height: 12), const CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)],
      ]))),
      // Torch toggle
      Positioned(top: 16, right: 16, child: IconButton(
        icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
        onPressed: () => controller.toggleTorch(),
      )),
    ]);
  }
}
