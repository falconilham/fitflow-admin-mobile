import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';

class FitFlowLogo extends StatelessWidget {
  const FitFlowLogo({
    super.key,
    this.fontSize = 20,
    this.alignment = MainAxisAlignment.start,
    this.showIcon = true,
    this.stacked = false,
    this.showTagline = false,
  });

  final double fontSize;
  final MainAxisAlignment alignment;
  final bool showIcon;
  final bool stacked;
  final bool showTagline;

  Widget _buildDumbbellIcon(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withAlpha(85),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildBrandText() {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.outfit(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.2,
          height: 1.1,
        ),
        children: const [
          TextSpan(
            text: 'FIT',
            style: TextStyle(color: Colors.white),
          ),
          TextSpan(
            text: 'FLOW.ID',
            style: TextStyle(color: AppColors.accent),
          ),
        ],
      ),
    );
  }

  Widget _buildTagline(double size) {
    return Text(
      'ALL IN ONE GYM MANAGEMENT',
      style: GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.8,
        color: const Color(0xFF94A3B8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconBoxSize = fontSize * 1.35;

    if (stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            _buildDumbbellIcon(iconBoxSize * 1.3),
            const SizedBox(height: 16),
          ],
          _buildBrandText(),
          if (showTagline) ...[
            const SizedBox(height: 8),
            _buildTagline(fontSize * 0.28),
          ],
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment == MainAxisAlignment.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: alignment,
          children: [
            if (showIcon) ...[
              _buildDumbbellIcon(iconBoxSize),
              SizedBox(width: fontSize * 0.45),
            ],
            _buildBrandText(),
          ],
        ),
        if (showTagline) ...[
          const SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.only(
              left: showIcon ? iconBoxSize + (fontSize * 0.45) : 0,
            ),
            child: _buildTagline(fontSize * 0.26),
          ),
        ],
      ],
    );
  }
}

/// Renders either the gym's White Label logo/name (when [branding.hasWhiteLabel])
/// or the default FitFlow brand logo.
class GymBrandHeaderLogo extends StatelessWidget {
  const GymBrandHeaderLogo({
    super.key,
    required this.branding,
    this.fontSize = 17,
  });

  final GymBranding branding;
  final double fontSize;

  static String? resolveLogoUrl(String? rawLogo) {
    if (rawLogo == null) return null;
    final trimmed = rawLogo.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:image')) {
      return trimmed;
    }
    final apiUrl = dotenv.env['API_URL'] ?? '';
    if (apiUrl.isEmpty) return trimmed;
    final base = apiUrl.endsWith('/') ? apiUrl.substring(0, apiUrl.length - 1) : apiUrl;
    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$base$path';
  }

  static Uint8List? tryDecodeDataUri(String uri) {
    if (!uri.startsWith('data:image')) return null;
    final commaIdx = uri.indexOf(',');
    if (commaIdx == -1 || commaIdx + 1 >= uri.length) return null;
    try {
      return base64Decode(uri.substring(commaIdx + 1));
    } catch (_) {
      return null;
    }
  }

  Widget _buildInitialBox(double boxSize, Color primary) {
    final initial = branding.name.trim().isNotEmpty
        ? branding.name.trim()[0].toUpperCase()
        : 'G';
    final textColor = primary.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    return Container(
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(boxSize * 0.24),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.outfit(
          fontSize: fontSize * 0.78,
          fontWeight: FontWeight.w900,
          color: textColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!branding.hasWhiteLabel) {
      return FitFlowLogo(fontSize: fontSize);
    }

    final primary = Theme.of(context).colorScheme.primary;
    final boxSize = fontSize * 1.45;
    final resolvedUrl = resolveLogoUrl(branding.logo);
    final dataBytes = resolvedUrl != null ? tryDecodeDataUri(resolvedUrl) : null;

    Widget logoWidget;
    if (dataBytes != null) {
      logoWidget = Container(
        width: boxSize,
        height: boxSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(boxSize * 0.24),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.memory(
          dataBytes,
          width: boxSize,
          height: boxSize,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildInitialBox(boxSize, primary),
        ),
      );
    } else if (resolvedUrl != null) {
      logoWidget = Container(
        width: boxSize,
        height: boxSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(boxSize * 0.24),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          resolvedUrl,
          width: boxSize,
          height: boxSize,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildInitialBox(boxSize, primary),
        ),
      );
    } else {
      logoWidget = _buildInitialBox(boxSize, primary);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logoWidget,
        SizedBox(width: fontSize * 0.45),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: Text(
            branding.name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
