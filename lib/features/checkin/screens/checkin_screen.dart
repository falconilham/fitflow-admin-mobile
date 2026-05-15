import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/drawer_menu_button.dart';
import '../../../shared/utils/error_handler.dart';

class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key});
  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> with WidgetsBindingObserver {
  final _searchCtrl = TextEditingController();
  final _cameraCtrl = MobileScannerController();
  String _tab = 'manual'; // 'manual' | 'scan'
  List<Member> _members = [];
  bool _searching = false;
  bool _isScanning = false;
  final Map<int, bool> _checkingIn = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    _cameraCtrl.stop();
    _cameraCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _cameraCtrl.stop();
    } else if (state == AppLifecycleState.resumed && _tab == 'scan') {
      _cameraCtrl.start();
    }
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
      final errMsg = ErrorHandler.parse(e);
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
      if (mounted) _showResult(false, false, '', ErrorHandler.parse(e));
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
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          granted ? (checkout ? '✅ Check-out Berhasil' : '✅ Check-in Berhasil') : '❌ Ditolak',
          style: TextStyle(color: granted ? AppColors.success : AppColors.error),
        ),
        content: Text('$name: $message', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (mounted && _tab == 'scan') {
                _cameraCtrl.start();
              }
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
        else Expanded(child: VisibilityDetector(
          key: const Key('checkin_scanner_visibility'),
          onVisibilityChanged: (info) {
            if (info.visibleFraction == 0 && mounted) {
              _cameraCtrl.stop();
            } else if (info.visibleFraction > 0 && mounted && _tab == 'scan') {
              _cameraCtrl.start();
            }
          },
          child: _ScanTab(controller: _cameraCtrl, onDetect: _handleQr, isScanning: _isScanning),
        )),
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
  const _ScanTab(
      {required this.controller,
      required this.onDetect,
      required this.isScanning});
  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    const boxSize = 250.0;
    const radius = 16.0;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final cutout = Rect.fromCenter(
          center: Offset(w / 2, h / 2),
          width: boxSize,
          height: boxSize,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            // Camera feed
            MobileScanner(controller: controller, onDetect: onDetect),

            // Dim overlay with see-through cutout (CustomPaint — reliable on Impeller)
            IgnorePointer(
              child: CustomPaint(
                size: Size(w, h),
                painter: _ScannerOverlayPainter(
                  cutout: cutout,
                  borderRadius: radius,
                  overlayColor: Colors.black.withAlpha(140),
                ),
              ),
            ),

            // Corner brackets around the cutout for visual affordance
            Positioned(
              left: cutout.left,
              top: cutout.top,
              width: cutout.width,
              height: cutout.height,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CornerBracketPainter(
                    color: AppColors.accent,
                    radius: radius,
                  ),
                ),
              ),
            ),

            // Caption + spinner under the cutout
            Positioned(
              left: 0,
              right: 0,
              top: cutout.bottom + 20,
              child: IgnorePointer(
                child: Column(
                  children: [
                    const Text(
                      'Arahkan QR Code ke dalam kotak',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (isScanning) ...[
                      const SizedBox(height: 12),
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: AppColors.accent, strokeWidth: 2.5),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Torch toggle
            Positioned(
              top: 16,
              right: 16,
              child: ValueListenableBuilder<MobileScannerState>(
                valueListenable: controller,
                builder: (_, state, __) {
                  final torchOn = state.torchState == TorchState.on;
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(120),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        color: torchOn ? AppColors.accent : Colors.white,
                      ),
                      onPressed: () => controller.toggleTorch(),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Rect cutout;
  final double borderRadius;
  final Color overlayColor;

  _ScannerOverlayPainter({
    required this.cutout,
    required this.borderRadius,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(cutout, Radius.circular(borderRadius)),
      );
    final paint = Paint()..color = overlayColor;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter old) =>
      old.cutout != cutout ||
      old.borderRadius != borderRadius ||
      old.overlayColor != overlayColor;
}

class _CornerBracketPainter extends CustomPainter {
  final Color color;
  final double radius;
  _CornerBracketPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const armLen = 28.0;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, armLen + radius)
        ..lineTo(0, radius)
        ..arcToPoint(
          Offset(radius, 0),
          radius: Radius.circular(radius),
        )
        ..lineTo(armLen + radius, 0),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - armLen - radius, 0)
        ..lineTo(size.width - radius, 0)
        ..arcToPoint(
          Offset(size.width, radius),
          radius: Radius.circular(radius),
        )
        ..lineTo(size.width, armLen + radius),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width, size.height - armLen - radius)
        ..lineTo(size.width, size.height - radius)
        ..arcToPoint(
          Offset(size.width - radius, size.height),
          radius: Radius.circular(radius),
        )
        ..lineTo(size.width - armLen - radius, size.height),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(armLen + radius, size.height)
        ..lineTo(radius, size.height)
        ..arcToPoint(
          Offset(0, size.height - radius),
          radius: Radius.circular(radius),
        )
        ..lineTo(0, size.height - armLen - radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter old) =>
      old.color != color || old.radius != radius;
}
