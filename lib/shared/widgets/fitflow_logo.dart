import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class FitFlowLogo extends StatelessWidget {
  const FitFlowLogo({
    super.key,
    this.fontSize = 20,
    this.alignment = MainAxisAlignment.start,
  });

  final double fontSize;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
              fontFamily: 'Inter',
            ),
            children: [
              const TextSpan(
                text: 'FIT',
                style: TextStyle(color: Colors.white),
              ),
              TextSpan(
                text: 'FLOW.ID',
                style: TextStyle(color: AppColors.accent),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
