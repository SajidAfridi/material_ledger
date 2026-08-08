import 'package:flutter/material.dart';

import '../constants/constants.dart';

/// The approved golden Yorks AC. & Ref. seal, presented as a clean white
/// circular badge so it reads on dark/blue splash and login panels as well as
/// the near-white navigation rail. Falls back to a brand mark if the asset
/// ever fails to load.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 40, this.shadow = true});

  final double size;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
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
        child: ClipOval(
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/logo.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => ColoredBox(
              color: AppColors.primary,
              child: Center(
                child: Icon(
                  Icons.ac_unit_rounded,
                  size: size * 0.5,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
