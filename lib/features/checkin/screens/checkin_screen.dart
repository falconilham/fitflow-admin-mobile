import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/dashboard/providers/dashboard_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/utils/error_handler.dart';
import '../../../shared/utils/format.dart';

class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen>
    with WidgetsBindingObserver {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  late MobileScannerController _cameraCtrl;
  String _tab = 'scan'; // 'scan' | 'manual'
  List<Member> _members = [];
  int? _selectedMemberId;
  bool _searching = false;
  bool _isScanning = false;
  bool _isStartingCamera = false;
  final Map<int, bool> _checkingIn = {};
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraCtrl = MobileScannerController(
      autoStart: true,
      detectionSpeed: DetectionSpeed.unrestricted,
      formats: const [BarcodeFormat.qrCode],
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _cameraCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_cameraCtrl.value.isInitialized) return;

    if (state == AppLifecycleState.paused) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed && _tab == 'scan') {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    if (!mounted || _isStartingCamera) return;
    if (_cameraCtrl.value.isRunning) return;
    _isStartingCamera = true;
    try {
      await _cameraCtrl.start();
    } catch (e) {
      debugPrint('[CheckIn] Camera start error: $e');
    } finally {
      if (mounted) _isStartingCamera = false;
    }
  }

  Future<void> _stopCamera() async {
    if (!_cameraCtrl.value.isInitialized || !_cameraCtrl.value.isRunning) {
      return;
    }
    try {
      await _cameraCtrl.stop();
    } catch (e) {
      debugPrint('[CheckIn] Camera stop error: $e');
    }
  }

  Future<void> _resetController() async {
    if (_isStartingCamera) return;
    _isStartingCamera = true;
    try {
      await _cameraCtrl.stop();
      await _cameraCtrl.dispose();
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _cameraCtrl = MobileScannerController(
        autoStart: true,
        detectionSpeed: DetectionSpeed.unrestricted,
        formats: const [BarcodeFormat.qrCode],
        facing: CameraFacing.back,
      );
      _isScanning = false;
    });

    _isStartingCamera = false;
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _members = [];
        _selectedMemberId = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) {
      setState(() {
        _members = [];
        _selectedMemberId = null;
      });
      return;
    }
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;

    setState(() => _searching = true);
    try {
      final rows = await ref
          .read(apiRepositoryProvider)
          .getMembers(gymId, search: query, limit: 20);
      if (!mounted) return;
      setState(() {
        _members = rows;
        if (rows.isEmpty) {
          _selectedMemberId = null;
        } else if (_selectedMemberId == null ||
            !rows.any((m) => m.id == _selectedMemberId)) {
          final firstActive = rows.firstWhere(
            (m) => m.displayStatus.toLowerCase() == 'active',
            orElse: () => rows.first,
          );
          _selectedMemberId = firstActive.id;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.parse(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _checkInManual(Member member) async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null || member.userId == null) return;
    setState(() => _checkingIn[member.id] = true);
    try {
      final res = await ref.read(apiRepositoryProvider).checkInByQr(
            gymId,
            member.userId!,
            member.id,
            method: 'manual',
          );

      final resStatus =
          res['access']?.toString() ?? res['status']?.toString() ?? '';
      final isGranted = resStatus == 'granted' || resStatus == 'success';
      final isCheckout = res['type']?.toString() == 'checkout';

      final memberMap =
          res['member'] as Map? ?? (res['data'] as Map?)?['member'] as Map?;
      final name = memberMap?['name']?.toString() ?? member.name;
      final message =
          res['message']?.toString() ?? res['status']?.toString() ?? '';

      if (isGranted) {
        ref.invalidate(dashboardStatsProvider);
        ref.invalidate(recentCheckInsProvider);
        unawaited(_search());
      }

      if (mounted) _showResult(isGranted, isCheckout, name, message);
    } catch (e) {
      final errMsg = ErrorHandler.parse(e);
      if (mounted) _showResult(false, false, member.name, errMsg);
    } finally {
      if (mounted) setState(() => _checkingIn.remove(member.id));
    }
  }

  Future<void> _processRawQr(String raw) async {
    if (_isScanning) return;
    setState(() => _isScanning = true);
    HapticFeedback.mediumImpact();

    try {
      final parsed = _parseQr(raw);
      if (parsed == null) {
        _showResult(false, false, '', 'Format QR tidak valid');
        return;
      }
      final res = await ref.read(apiRepositoryProvider).checkInByQr(
            parsed['gymId'] as int,
            parsed['userId'] as int,
            parsed['membershipId'] as int,
            qrToken: parsed['qrToken'] as String?,
            method: 'qr',
          );

      final resStatus =
          res['access']?.toString() ?? res['status']?.toString() ?? '';
      final isGranted = resStatus == 'granted' || resStatus == 'success';
      final isCheckout = res['type']?.toString() == 'checkout';

      final memberMap =
          res['member'] as Map? ?? (res['data'] as Map?)?['member'] as Map?;
      final name = memberMap?['name']?.toString() ?? '';
      final message =
          res['message']?.toString() ?? res['status']?.toString() ?? '';

      if (isGranted) {
        ref.invalidate(dashboardStatsProvider);
        ref.invalidate(recentCheckInsProvider);
      }

      if (mounted) _showResult(isGranted, isCheckout, name, message);
    } catch (e) {
      if (mounted) _showResult(false, false, '', ErrorHandler.parse(e));
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _handleQr(BarcodeCapture capture) async {
    if (_isScanning) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    await _processRawQr(raw);
  }

  Map<String, dynamic>? _parseQr(String raw) {
    try {
      final trimmed = raw.trim();

      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        final uri = Uri.tryParse(trimmed);
        if (uri != null) {
          final tokenParam = uri.queryParameters['qrToken'] ??
              uri.queryParameters['token'] ??
              uri.queryParameters['code'];
          if (tokenParam != null && tokenParam.isNotEmpty) {
            final fromToken = _parseQr(tokenParam);
            if (fromToken != null) return fromToken;
          }

          final segments = uri.pathSegments;
          final qrIndex = segments.indexOf('qr');
          if (qrIndex != -1 && segments.length >= qrIndex + 3) {
            final uId = int.tryParse(segments[qrIndex + 1]);
            final mId = int.tryParse(segments[qrIndex + 2]);
            if (uId != null && mId != null) {
              return {
                'userId': uId,
                'gymId': ref.read(authProvider).valueOrNull?.activeGymId ?? 0,
                'membershipId': mId,
              };
            }
          }
        }
      }

      if (trimmed.contains('.') && trimmed.split('.').length == 3) {
        final parts = trimmed.split('.');
        final payloadNormalized = base64Url.normalize(parts[1]);
        final decodedBytes = base64Url.decode(payloadNormalized);
        final decodedStr = utf8.decode(decodedBytes);
        final dynamic jwtData = jsonDecode(decodedStr);

        if (jwtData is Map) {
          final userId = int.tryParse(jwtData['userId']?.toString() ?? '') ?? 0;
          final membershipId = int.tryParse(
                  (jwtData['memberId'] ?? jwtData['membershipId'])
                          ?.toString() ??
                      '') ??
              0;
          final gymId = int.tryParse(jwtData['gymId']?.toString() ?? '') ??
              (ref.read(authProvider).valueOrNull?.activeGymId ?? 0);

          return {
            'userId': userId,
            'gymId': gymId,
            'membershipId': membershipId,
            'qrToken': trimmed,
          };
        }
      }

      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          final decodedJson = jsonDecode(trimmed);
          if (decodedJson is Map) {
            final userId =
                int.tryParse(decodedJson['userId']?.toString() ?? '') ?? 0;
            final membershipId = int.tryParse(
                    (decodedJson['memberId'] ?? decodedJson['membershipId'])
                            ?.toString() ??
                        '') ??
                0;
            final gymId =
                int.tryParse(decodedJson['gymId']?.toString() ?? '') ??
                    (ref.read(authProvider).valueOrNull?.activeGymId ?? 0);

            if (userId > 0 || membershipId > 0) {
              return {
                'userId': userId,
                'gymId': gymId,
                'membershipId': membershipId,
                if (decodedJson['qrToken'] != null)
                  'qrToken': decodedJson['qrToken'].toString(),
              };
            }
          }
        } catch (_) {}
      }

      final decoded = trimmed.replaceAll("'", '"');
      final Map<String, dynamic> json = Map<String, dynamic>.from(
        RegExp(r'"(\w+)":\s*(\d+)').allMatches(decoded).fold(
          <String, dynamic>{},
          (map, m) => map..['${m.group(1)}'] = int.parse(m.group(2)!),
        ),
      );
      if (json.containsKey('userId') &&
          json.containsKey('gymId') &&
          json.containsKey('membershipId')) {
        return {
          'userId': json['userId'] as int,
          'gymId': json['gymId'] as int,
          'membershipId': json['membershipId'] as int,
        };
      }

      final parts = trimmed.split(':');
      if (parts.length == 2) {
        final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
        final uId = int.tryParse(parts[0]);
        final mId = int.tryParse(parts[1]);
        if (gymId != null && uId != null && mId != null) {
          return {
            'userId': uId,
            'gymId': gymId,
            'membershipId': mId,
          };
        }
      } else if (parts.length == 3) {
        final gId = int.tryParse(parts[0]);
        final uId = int.tryParse(parts[1]);
        final mId = int.tryParse(parts[2]);
        if (gId != null && uId != null && mId != null) {
          return {
            'userId': uId,
            'gymId': gId,
            'membershipId': mId,
          };
        }
      }
    } catch (_) {}
    return null;
  }

  void _showResult(bool granted, bool checkout, String name, String message) {
    final l10n = AppLocalizations.of(context)!;
    int countdown = 3;
    Timer? timer;
    showDialog<void>(
      context: context,
      barrierDismissible: !granted,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            if (granted && timer == null) {
              timer = Timer.periodic(const Duration(seconds: 1), (t) {
                if (countdown > 1) {
                  if (dialogCtx.mounted) {
                    setDialogState(() => countdown--);
                  }
                } else {
                  t.cancel();
                  if (dialogCtx.mounted) Navigator.of(ctx).pop();
                }
              });
            }

            return AlertDialog(
              backgroundColor: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: granted ? AppColors.success : AppColors.error,
                  width: 1.5,
                ),
              ),
              title: Row(
                children: [
                  Icon(
                    granted
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: granted ? AppColors.success : AppColors.error,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      granted
                          ? (checkout
                              ? l10n.checkOutSuccessTitle
                              : l10n.checkInSuccessTitle)
                          : l10n.checkInDeniedTitle,
                      style: GoogleFonts.figtree(
                        color: granted ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (name.isNotEmpty) ...[
                    Text(
                      name,
                      style: GoogleFonts.figtree(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    message.isNotEmpty
                        ? message
                        : (granted ? 'Selamat berlatih!' : 'Akses ditolak.'),
                    style: GoogleFonts.figtree(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              actions: [
                if (!granted)
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: () {
                      timer?.cancel();
                      Navigator.of(ctx).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.background,
                    ),
                    child: Text('OK (${countdown}s)'),
                  ),
              ],
            );
          },
        );
      },
    ).then((_) {
      timer?.cancel();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _isScanning = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final stats = ref.watch(dashboardStatsProvider).valueOrNull;
    final checkInsToday = stats?.dailyCheckIns ?? 0;
    final currentlyInside = stats?.currentlyInside ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.checkInTitle,
                        style: GoogleFonts.figtree(
                          color: AppColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.checkInSubtitle,
                        style: GoogleFonts.figtree(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Ringkasan kehadiran bar ──────────────────────────
                      Container(
                        height: 74,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    checkInsToday.toString(),
                                    style: GoogleFonts.figtree(
                                      color: AppColors.textPrimary,
                                      fontSize: 25,
                                      fontWeight: FontWeight.w600,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    l10n.checkInTodayLabel,
                                    style: GoogleFonts.figtree(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 42,
                              color: AppColors.border,
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentlyInside.toString(),
                                    style: GoogleFonts.figtree(
                                      color: AppColors.textPrimary,
                                      fontSize: 25,
                                      fontWeight: FontWeight.w600,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    l10n.insideGymLabel,
                                    style: GoogleFonts.figtree(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Metode check-in Segmented Toggle ─────────────────
                      Container(
                        height: 44,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            _SegmentTab(
                              icon: LucideIcons.qrCode,
                              label: l10n.scanQrTab,
                              active: _tab == 'scan',
                              onTap: () {
                                if (_tab == 'scan') return;
                                setState(() => _tab = 'scan');
                                _startCamera();
                              },
                            ),
                            _SegmentTab(
                              icon: LucideIcons.pencil,
                              label: l10n.manualCheckInTab,
                              active: _tab == 'manual',
                              onTap: () {
                                if (_tab == 'manual') return;
                                setState(() => _tab = 'manual');
                                _stopCamera();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: IndexedStack(
                    index: _tab == 'scan' ? 0 : 1,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: _ScanTab(
                            controller: _cameraCtrl,
                            onDetect: _handleQr,
                            isScanning: _isScanning,
                            onRetry: _resetController,
                          ),
                        ),
                      ),
                      _ManualTab(
                        searchCtrl: _searchCtrl,
                        searchFocus: _searchFocus,
                        members: _members,
                        selectedMemberId: _selectedMemberId,
                        searching: _searching,
                        checkingIn: _checkingIn,
                        onChanged: _onSearchChanged,
                        onSearch: _search,
                        onSelect: (id) =>
                            setState(() => _selectedMemberId = id),
                        onCheckIn: _checkInManual,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: active ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? AppColors.background : AppColors.textSecondary,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.figtree(
                    color:
                        active ? AppColors.background : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Manual search tab ────────────────────────────────────────────────────────

class _ManualTab extends StatelessWidget {
  const _ManualTab({
    required this.searchCtrl,
    required this.searchFocus,
    required this.members,
    required this.selectedMemberId,
    required this.searching,
    required this.checkingIn,
    required this.onChanged,
    required this.onSearch,
    required this.onSelect,
    required this.onCheckIn,
  });

  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  final List<Member> members;
  final int? selectedMemberId;
  final bool searching;
  final Map<int, bool> checkingIn;
  final ValueChanged<String> onChanged;
  final VoidCallback onSearch;
  final ValueChanged<int> onSelect;
  final Future<void> Function(Member) onCheckIn;

  String _maskPhone(String? raw) {
    final p = (raw ?? '').trim();
    if (p.isEmpty) return '';
    if (p.length <= 6) return p;
    final prefix = p.substring(0, 4);
    final suffix = p.substring(p.length - 4);
    return '$prefix •••• $suffix';
  }

  String _memberIdentitySubtitle(Member m) {
    final idStr = (m.memberId ?? '').trim().isNotEmpty
        ? m.memberId!.trim()
        : 'MEM-${m.id}';
    final masked = _maskPhone(m.phone);
    if (masked.isEmpty) return idStr;
    return '$idStr · $masked';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasQuery = searchCtrl.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: searchCtrl,
            focusNode: searchFocus,
            onChanged: onChanged,
            onSubmitted: (_) => onSearch(),
            style: GoogleFonts.figtree(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.card,
              hintText: l10n.searchMemberPlaceholder,
              hintStyle: GoogleFonts.figtree(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                LucideIcons.search,
                size: 19,
                color: AppColors.accent,
              ),
              suffixIcon: hasQuery
                  ? IconButton(
                      icon: const Icon(
                        LucideIcons.x,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        searchCtrl.clear();
                        onChanged('');
                      },
                    )
                  : null,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: hasQuery ? AppColors.accent : AppColors.border,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.accent,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (hasQuery && !searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              l10n.membersFoundCount(members.length),
              style: GoogleFonts.figtree(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        Expanded(
          child: searching
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accent,
                    strokeWidth: 2,
                  ),
                )
              : members.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          hasQuery
                              ? l10n.noMembersFound
                              : l10n.searchMemberPrompt,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.figtree(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
                      itemCount: members.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final m = members[i];
                        final isSelected = m.id == selectedMemberId;
                        final status = m.displayStatus.toLowerCase();
                        final isActive = status == 'active';
                        final isExpired = status == 'expired';
                        final isSuspended = status == 'suspended';

                        if (isSelected) {
                          return _SelectedMemberCard(
                            member: m,
                            identitySubtitle: _memberIdentitySubtitle(m),
                            isActive: isActive,
                            isExpired: isExpired,
                            isSuspended: isSuspended,
                            isSubmitting: checkingIn[m.id] == true,
                            onConfirm: () => onCheckIn(m),
                          );
                        }

                        return _CompactMemberCard(
                          member: m,
                          identitySubtitle: _memberIdentitySubtitle(m),
                          isActive: isActive,
                          isExpired: isExpired,
                          isSuspended: isSuspended,
                          onTap: () => onSelect(m.id),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _SelectedMemberCard extends StatelessWidget {
  const _SelectedMemberCard({
    required this.member,
    required this.identitySubtitle,
    required this.isActive,
    required this.isExpired,
    required this.isSuspended,
    required this.isSubmitting,
    required this.onConfirm,
  });

  final Member member;
  final String identitySubtitle;
  final bool isActive;
  final bool isExpired;
  final bool isSuspended;
  final bool isSubmitting;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isVisitPkg = member.hasVisitPackage ||
        (member.packageType ?? '').toUpperCase() == 'SESSION';
    final packageTitle = (member.packageName ?? '').trim().isNotEmpty
        ? member.packageName!.trim()
        : 'Membership Reguler';

    final statusBg = isActive
        ? AppColors.successPillBg
        : AppColors.warningPillBg;
    final statusFg = isActive
        ? AppColors.successPillText
        : AppColors.warningPillText;
    final statusText = isActive
        ? l10n.membershipActiveBadge
        : isExpired
            ? l10n.membershipExpiredBadge
            : isSuspended
                ? l10n.membershipSuspendedBadge
                : l10n.membershipInactiveBadge;

    final attendanceText = member.checkedInToday
        ? l10n.checkedInBadge
        : l10n.notCheckedInLabel;

    final ctaLabel = member.isInsideGym
        ? l10n.confirmCheckOutBtn
        : l10n.confirmCheckInBtn;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  member.name,
                  style: GoogleFonts.figtree(
                    color: AppColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                LucideIcons.check,
                size: 20,
                color: AppColors.accent,
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            identitySubtitle,
            style: GoogleFonts.figtree(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              statusText,
              style: GoogleFonts.figtree(
                color: statusFg,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      packageTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.figtree(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (isVisitPkg && member.totalSessions != null)
                      Text(
                        l10n.gymSessionsLabel(
                          member.remainingSessions ?? 0,
                          member.totalSessions ?? 0,
                        ),
                        style: GoogleFonts.figtree(
                          color: AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Text(
                        l10n.validUntilLabel(formatDate(member.endDate)),
                        style: GoogleFonts.figtree(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                attendanceText,
                style: GoogleFonts.figtree(
                  color: member.checkedInToday
                      ? AppColors.infoPillText
                      : AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: isSubmitting ? null : onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isActive ? AppColors.accent : AppColors.iconSurface,
                foregroundColor:
                    isActive ? AppColors.background : AppColors.textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.background,
                      ),
                    )
                  : Icon(
                      LucideIcons.check,
                      size: 17,
                      color: isActive
                          ? AppColors.background
                          : AppColors.textSecondary,
                    ),
              label: Text(
                ctaLabel,
                style: GoogleFonts.figtree(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactMemberCard extends StatelessWidget {
  const _CompactMemberCard({
    required this.member,
    required this.identitySubtitle,
    required this.isActive,
    required this.isExpired,
    required this.isSuspended,
    required this.onTap,
  });

  final Member member;
  final String identitySubtitle;
  final bool isActive;
  final bool isExpired;
  final bool isSuspended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    late final Color pillBg;
    late final Color pillFg;
    late final String pillLabel;

    if (isExpired) {
      pillBg = AppColors.warningPillBg;
      pillFg = AppColors.warningPillText;
      pillLabel = l10n.membershipExpiredBadge;
    } else if (isSuspended) {
      pillBg = AppColors.warningPillBg;
      pillFg = AppColors.warningPillText;
      pillLabel = l10n.membershipSuspendedBadge;
    } else if (member.checkedInToday) {
      pillBg = AppColors.infoPillBg;
      pillFg = AppColors.infoPillText;
      pillLabel = l10n.checkedInBadge;
    } else if (isActive) {
      pillBg = AppColors.successPillBg;
      pillFg = AppColors.successPillText;
      pillLabel = l10n.membershipActiveBadge;
    } else {
      pillBg = AppColors.iconSurface;
      pillFg = AppColors.textSecondary;
      pillLabel = l10n.membershipInactiveBadge;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.figtree(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    identitySubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.figtree(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: pillBg,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                pillLabel,
                style: GoogleFonts.figtree(
                  color: pillFg,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── QR Scan tab ──────────────────────────────────────────────────────────────

class _ScanTab extends StatefulWidget {
  const _ScanTab({
    required this.controller,
    required this.onDetect,
    required this.isScanning,
    required this.onRetry,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final bool isScanning;
  final VoidCallback onRetry;

  @override
  State<_ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<_ScanTab> {
  double _zoomScale = 0.0;

  void _setZoom(double zoom) {
    setState(() => _zoomScale = zoom);
    try {
      widget.controller.setZoomScale(zoom);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    const boxSize = 250.0;
    const radius = 16.0;

    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: widget.controller,
      builder: (context, state, _) {
        final hasError = state.error != null;
        final isReady = state.isInitialized && !hasError;

        return LayoutBuilder(
          builder: (ctx, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final cutout = Rect.fromCenter(
              center: Offset(w / 2, h / 2 - 24),
              width: boxSize,
              height: boxSize,
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  key: ValueKey('scanner_${widget.controller.hashCode}'),
                  controller: widget.controller,
                  onDetect: widget.onDetect,
                  fit: BoxFit.cover,
                  placeholderBuilder: (ctx, child) {
                    return Container(
                      color: AppColors.card,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: AppColors.accent,
                              strokeWidth: 2.5,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Menyiapkan kamera...',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  errorBuilder: (ctx, error, child) {
                    String title = 'Kamera Tidak Tersedia';
                    String desc =
                        'Terjadi kesalahan saat menginisialisasi kamera.';

                    if (error.errorCode ==
                        MobileScannerErrorCode.permissionDenied) {
                      title = 'Izin Kamera Dibutuhkan';
                      desc =
                          'FitFlow Admin memerlukan izin kamera untuk memindai QR code check-in member.';
                    } else if (error.errorCode ==
                        MobileScannerErrorCode.unsupported) {
                      title = 'Perangkat Tidak Didukung';
                      desc = 'Kamera tidak didukung pada perangkat ini.';
                    }

                    return Container(
                      color: AppColors.card,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.error.withAlpha(30),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.videocam_off_rounded,
                                size: 42,
                                color: AppColors.error,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              title,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              desc,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: AppColors.background,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text(
                                'Coba Lagi',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onPressed: widget.onRetry,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (isReady) ...[
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
                  Positioned(
                    left: 0,
                    right: 0,
                    top: cutout.bottom + 14,
                    child: Column(
                      children: [
                        const Text(
                          'Posisikan QR Code di dalam kotak',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _ZoomChip(
                              label: '1.0x',
                              active: _zoomScale == 0.0,
                              onTap: () => _setZoom(0.0),
                            ),
                            const SizedBox(width: 8),
                            _ZoomChip(
                              label: '1.5x',
                              active: _zoomScale == 0.25,
                              onTap: () => _setZoom(0.25),
                            ),
                            const SizedBox(width: 8),
                            _ZoomChip(
                              label: '2.0x',
                              active: _zoomScale == 0.5,
                              onTap: () => _setZoom(0.5),
                            ),
                          ],
                        ),
                        if (widget.isScanning) ...[
                          const SizedBox(height: 10),
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: AppColors.accent,
                              strokeWidth: 2.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 64,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(120),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                        ),
                        onPressed: widget.onRetry,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(120),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          state.torchState == TorchState.on
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          color: state.torchState == TorchState.on
                              ? AppColors.accent
                              : Colors.white,
                        ),
                        onPressed: () => widget.controller.toggleTorch(),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _ZoomChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ZoomChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.accent : Colors.black.withAlpha(160),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? AppColors.accent : Colors.white24,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
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
