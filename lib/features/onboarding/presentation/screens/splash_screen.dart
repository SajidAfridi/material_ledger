import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/yorks_v1_shell_strings.dart';
import '../../../../shared/providers/language_provider.dart';

/// The approved R35 access splash.
///
/// This is intentionally a short, calm hand-off into secure sign-in. It has no
/// product state or authorization logic: those remain owned by the router and
/// the auth controller after the splash ends.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.navy,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // This retained route exists only to complete the historical first-run
      // preference. Platform and runtime boot surfaces now own brand continuity;
      // no user waits on a presentation timer.
      if (!ref.read(onboardingCompleteProvider)) {
        unawaited(ref.read(onboardingCompleteProvider.notifier).complete());
      }
      context.go(RoutePaths.login);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mobile = YorksMobileUi.isActive(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: mobile
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF041E42),
                    Color(0xFF00183A),
                    Color(0xFF000E26),
                  ],
                  stops: [0, 0.54, 1],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF081D36),
                    AppColors.navy,
                    AppColors.navyHover,
                  ],
                  stops: [0, 0.58, 1],
                ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!mobile) ...[
              const IgnorePointer(
                child: CustomPaint(painter: _SplashGridPainter()),
              ),
              const IgnorePointer(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: 300,
                    child: CustomPaint(painter: _SiteLinePainter()),
                  ),
                ),
              ),
            ],
            SafeArea(
              child: mobile
                  ? const _SplashMobileContent()
                  : const Center(child: _SplashContent()),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashMobileContent extends StatelessWidget {
  const _SplashMobileContent();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 22),
      child: Column(
        children: [
          SizedBox(height: constraints.maxHeight < 760 ? 148 : 204),
          const BrandLogo(size: 158, shadow: true),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                YorksV1ShellStrings.companyName.primary,
                textAlign: TextAlign.center,
                style: AppTypography.headlineMedium.copyWith(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.18,
                  letterSpacing: -0.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF1677FF),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            YorksV1ShellStrings.projectManagementSystem.primary,
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(
              color: Colors.white.withValues(alpha: .72),
              fontSize: 16,
              height: 1.52,
            ),
          ),
          const Spacer(flex: 3),
          const Icon(
            Icons.verified_user_outlined,
            size: 42,
            color: Color(0xFF1677FF),
          ),
          const SizedBox(height: 12),
          Text(
            YorksV1ShellStrings.oneSourceOfTruthForEveryProject.primary,
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(
              color: Colors.white.withValues(alpha: .75),
              fontSize: 15,
            ),
          ),
          const Spacer(flex: 4),
          SizedBox(
            width: 188,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              child: const LinearProgressIndicator(
                minHeight: 5,
                backgroundColor: Color(0xFF12345F),
                valueColor: AlwaysStoppedAnimation(Color(0xFF1677FF)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SplashContent extends StatelessWidget {
  const _SplashContent();

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 480),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
              color: Colors.white.withValues(alpha: 0.06),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const BrandLogo(size: 108, shadow: false),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            YorksV1ShellStrings.companyName.primary,
            textAlign: TextAlign.center,
            style: AppTypography.headlineLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            YorksV1ShellStrings.companyLegalName.primary,
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(
              color: Colors.white.withValues(alpha: 0.76),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            YorksV1ShellStrings.operationalWorkspace.primary.toUpperCase(),
            textAlign: TextAlign.center,
            style: AppTypography.eyebrow.copyWith(
              color: const Color(0xFF82BCFF),
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.colossal),
          Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                child: LinearProgressIndicator(
                  value: 1,
                  minHeight: 5,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF55A9FF)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                YorksV1ShellStrings.preparingWorkspace.primary,
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 17,
                color: Colors.white.withValues(alpha: 0.58),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                YorksV1ShellStrings.secureProjectWorkspace.primary,
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.64),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SplashGridPainter extends CustomPainter {
  const _SplashGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    const step = 46.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SplashGridPainter oldDelegate) => false;
}

class _SiteLinePainter extends CustomPainter {
  const _SiteLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.62)
      ..lineTo(size.width * 0.06, size.height * 0.43)
      ..lineTo(size.width * 0.12, size.height * 0.62)
      ..lineTo(size.width * 0.18, size.height * 0.3)
      ..lineTo(size.width * 0.25, size.height * 0.57)
      ..lineTo(size.width * 0.33, size.height * 0.38)
      ..lineTo(size.width * 0.42, size.height * 0.61)
      ..lineTo(size.width * 0.51, size.height * 0.25)
      ..lineTo(size.width * 0.6, size.height * 0.52)
      ..lineTo(size.width * 0.69, size.height * 0.34)
      ..lineTo(size.width * 0.78, size.height * 0.61)
      ..lineTo(size.width * 0.88, size.height * 0.4)
      ..lineTo(size.width, size.height * 0.57)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );
  }

  @override
  bool shouldRepaint(covariant _SiteLinePainter oldDelegate) => false;
}
