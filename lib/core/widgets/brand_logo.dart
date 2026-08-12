import 'package:flutter/foundation.dart' show kIsWeb;
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

  // The full-resolution PNG remains the canonical document/native asset. The
  // web shell never renders this mark above 84 logical pixels, so its compact
  // 256px counterpart preserves the visible seal while avoiding a 1.3 MB
  // first-page image transfer.
  static const _webAsset = 'assets/branding/yorks_emblem_web.png';
  static const _nativeAsset = 'assets/logo.png';

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
            kIsWeb ? _webAsset : _nativeAsset,
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
