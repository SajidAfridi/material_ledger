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

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  Timer? _continueTimer;

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
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..forward();
    _continueTimer = Timer(const Duration(milliseconds: 1250), () async {
      if (!mounted) return;
      // The approved R35 prototype goes directly from splash to sign-in. The
      // old first-run language gate could redirect that hand-off back to
      // splash forever on a fresh browser profile. English is the configured
      // default; users can change the display language later from Profile.
      if (!ref.read(onboardingCompleteProvider)) {
        await ref.read(onboardingCompleteProvider.notifier).complete();
      }
      if (mounted) context.go(RoutePaths.login);
    });
  }

  @override
  void dispose() {
    _continueTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF081D36), AppColors.navy, AppColors.navyHover],
          stops: [0, 0.58, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
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
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _progressController,
                  curve: const Interval(0, 0.5, curve: Curves.easeOut),
                ),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1).animate(
                    CurvedAnimation(
                      parent: _progressController,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: _SplashContent(progress: _progressController),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SplashContent extends StatelessWidget {
  const _SplashContent({required this.progress});

  final Animation<double> progress;

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
          AnimatedBuilder(
            animation: progress,
            builder: (context, _) => Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  child: LinearProgressIndicator(
                    value: 0.1 + (progress.value * 0.9),
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
