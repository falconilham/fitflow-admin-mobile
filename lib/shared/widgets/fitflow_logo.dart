import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class FitFlowLogo extends StatelessWidget {
  const FitFlowLogo({
    super.key,
    this.fontSize = 20,
    this.alignment = MainAxisAlignment.start,
    this.showIcon = true,
    this.stacked = false,
  });

  final double fontSize;
  final MainAxisAlignment alignment;
  final bool showIcon;
  final bool stacked;

  Widget _buildDumbbellIcon(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(size * 0.26),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withAlpha(70),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Transform.rotate(
          angle: -0.785398, // 45 degree tilt matching official brand svg
          child: Icon(
            Icons.fitness_center_rounded,
            size: size * 0.60,
            color: Colors.black,
          ),
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
          letterSpacing: -1.0,
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

  @override
  Widget build(BuildContext context) {
    final iconBoxSize = fontSize * 1.35;

    if (stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            _buildDumbbellIcon(iconBoxSize * 1.25),
            const SizedBox(height: 16),
          ],
          _buildBrandText(),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      children: [
        if (showIcon) ...[
          _buildDumbbellIcon(iconBoxSize),
          SizedBox(width: fontSize * 0.45),
        ],
        _buildBrandText(),
      ],
    );
  }
}
