import 'package:flutter/material.dart';

import '../constants/constants.dart';

/// The Yorks Air Conditioning & Ref. emblem, presented as a clean white circular
/// badge so the blue-on-white logo reads on any surface — the dark/blue splash &
/// login panels as well as the near-white nav rail. Falls back to a brand
/// monogram tile if the asset ever fails to load.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 40, this.shadow = true});

  final double size;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: AppColors.scrim.withValues(alpha: 0.18),
                  blurRadius: size * 0.16,
                  offset: Offset(0, size * 0.06),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/logo.png',
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: AppColors.primary,
          alignment: Alignment.center,
          child: Icon(
            Icons.ac_unit_rounded,
            size: size * 0.5,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
