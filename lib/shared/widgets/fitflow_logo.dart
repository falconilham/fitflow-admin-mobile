import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_theme.dart';

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
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withAlpha(85),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          LucideIcons.dumbbell,
          size: size * 0.58,
          color: Colors.black,
        ),
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
