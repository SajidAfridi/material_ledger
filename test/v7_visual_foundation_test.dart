import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:material_ledger/core/constants/constants.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/core/widgets/widgets.dart';

void main() {
  setUpAll(() async {
    final nexusFontLoader = FontLoader('NexusSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final flutterCache = _flutterCacheDirectory();
    final iconBytes = await File(
      '${flutterCache.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes();
    final iconFontLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(iconBytes)));

    await Future.wait([nexusFontLoader.load(), iconFontLoader.load()]);
  });

  group('V7 design tokens', () {
    test('match the approved client palette and workspace geometry', () {
      expect(AppColors.ink, const Color(0xFF132033));
      expect(AppColors.navy, const Color(0xFF0D2F57));
      expect(AppColors.blue, const Color(0xFF1D68D9));
      expect(AppColors.success, const Color(0xFF0D8B63));
      expect(AppColors.warning, const Color(0xFFAD6A00));
      expect(AppColors.error, const Color(0xFFC23737));
      expect(AppColors.surfaceContainerLowest, Colors.white);
      expect(AppColors.line, const Color(0xFFDCE3EC));

      expect(AppSpacing.radiusLg, 14);
      expect(AppSpacing.sidebarWidth, 246);
      expect(AppSpacing.topBarHeight, 64);
      expect(AppSpacing.pageMaxWidth, 1740);
      expect(AppSpacing.inspectorWidth, 330);
      expect(AppSpacing.minTapTarget, greaterThanOrEqualTo(44));
    });
  });

  group('V7 components', () {
    testWidgets('expose state, current owner and audit metadata', (
      tester,
    ) async {
      await _pumpFoundation(tester, const Size(980, 800));

      expect(find.text('Current state: Active'), findsOneWidget);
      expect(find.text('Current action owner: Imran Khan'), findsOneWidget);
      expect(find.text('Ali Raza'), findsNWidgets(2));
      expect(find.text('Procurement'), findsOneWidget);
      expect(find.text('24 Jul 2026, 14:32'), findsOneWidget);

      final chipSize = tester.getSize(find.text('Active').last);
      expect(chipSize.height, lessThanOrEqualTo(25));
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps all touch actions at least 44 pixels high', (
      tester,
    ) async {
      await _pumpFoundation(tester, const Size(390, 844));

      for (final finder in [
        find.byKey(const ValueKey('foundation-export')),
        find.byKey(const ValueKey('foundation-primary-action')),
      ]) {
        expect(tester.getSize(finder).height, greaterThanOrEqualTo(44));
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('V7 responsive shell', () {
    testWidgets('uses a fixed inspector rail on desktop', (tester) async {
      await _pumpFoundation(tester, const Size(1280, 800));

      final primary = tester.getRect(
        find.byKey(NexusPageShell.primaryContentKey),
      );
      final inspector = tester.getRect(find.byKey(NexusPageShell.inspectorKey));

      expect(inspector.left, greaterThan(primary.right));
      expect(inspector.width, AppSpacing.inspectorWidth);
      expect(tester.takeException(), isNull);
    });

    testWidgets('stacks the inspector below work on tablet and mobile', (
      tester,
    ) async {
      for (final size in [const Size(900, 900), const Size(390, 844)]) {
        await _pumpFoundation(tester, size);
        final primary = tester.getRect(
          find.byKey(NexusPageShell.primaryContentKey),
        );
        final inspector = tester.getRect(
          find.byKey(NexusPageShell.inspectorKey),
        );

        expect(inspector.top, greaterThan(primary.bottom));
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('V7 visual contracts', () {
    testWidgets('desktop foundation golden', (tester) async {
      await _pumpFoundation(tester, const Size(1280, 800));

      await expectLater(
        find.byType(NexusPageShell),
        matchesGoldenFile('goldens/v7_visual_foundation_desktop.png'),
      );
    });

    testWidgets('mobile foundation golden', (tester) async {
      await _pumpFoundation(tester, const Size(390, 844));

      await expectLater(
        find.byType(NexusPageShell),
        matchesGoldenFile('goldens/v7_visual_foundation_mobile.png'),
      );
    });
  });
}

Directory _flutterCacheDirectory() {
  var directory = File(Platform.resolvedExecutable).parent;
  for (var level = 0; level < 8; level++) {
    if (directory.path.endsWith('${Platform.pathSeparator}cache')) {
      return directory;
    }
    directory = directory.parent;
  }
  throw StateError('Could not locate the Flutter cache from the test runner');
}

Future<void> _pumpFoundation(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(body: _FoundationFixture()),
    ),
  );
  await tester.pumpAndSettle();
}

class _FoundationFixture extends StatelessWidget {
  const _FoundationFixture();

  @override
  Widget build(BuildContext context) {
    return NexusPageShell(
      eyebrow: 'Project workspace',
      title: 'Nexus 4 Station',
      description:
          'Connected project, request, sourcing, order and receipt records.',
      actions: [
        OutlinedButton.icon(
          key: const ValueKey('foundation-export'),
          onPressed: () {},
          icon: const Icon(Icons.download_outlined, size: 16),
          label: const Text('Export'),
        ),
        ElevatedButton.icon(
          key: const ValueKey('foundation-primary-action'),
          onPressed: () {},
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
          label: const Text('New material request'),
        ),
      ],
      inspector: NexusSectionCard(
        title: 'Responsibility',
        description: 'Clear ownership for every important step.',
        child: Column(
          children: const [
            _Fact(label: 'Assigned engineer', value: 'Imran Khan'),
            SizedBox(height: AppSpacing.md),
            _Fact(label: 'Procurement owner', value: 'Ali Raza'),
            SizedBox(height: AppSpacing.md),
            _Fact(label: 'Technical approver', value: 'Imran Khan'),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CurrentActionCard(
            title: 'Current state: Active',
            message:
                'Execution is open. 1 material request is currently in progress.',
            ownerLabel: 'Current action owner',
            ownerName: 'Imran Khan',
          ),
          const SizedBox(height: AppSpacing.lg),
          NexusSectionCard(
            title: 'Connected work',
            description: 'Every update records the user, role and time.',
            trailing: const StatusChip(
              label: 'Active',
              tone: NexusStatusTone.success,
              showDot: true,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    StatusChip(
                      label: 'Sourcing',
                      tone: NexusStatusTone.warning,
                    ),
                    StatusChip(label: 'Linked', tone: NexusStatusTone.info),
                    StatusChip(
                      label: 'Partially received',
                      tone: NexusStatusTone.purple,
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                AuditTrailItem(
                  action: 'Completed procurement arrangement',
                  detail: 'Plan sent to Engineer for final approval.',
                  actor: 'Ali Raza',
                  role: 'Procurement',
                  timestamp: '24 Jul 2026, 14:32',
                  showDivider: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTypography.bodySmall)),
        const SizedBox(width: AppSpacing.sm),
        Text(value, style: AppTypography.labelLarge),
      ],
    );
  }
}
