import 'dart:async';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_ledger/shared/models/yorks_v1_calculator_workspace.dart';
import 'package:material_ledger/shared/models/app_language.dart';
import 'package:material_ledger/shared/controllers/yorks_v1_calculator_controller.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_calculator_repository.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_project_repository.dart';
import 'package:material_ledger/shared/providers/yorks_v1_calculator_provider.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/features/engineering_tools/presentation/screens/yorks_calculator_workspace.dart';
import 'package:material_ledger/features/engineering_tools/presentation/screens/yorks_v1_engineering_calculator_screens.dart';

class FakeCalculatorRpc implements YorksV1ProjectRpcClient {
  Object? fail;
  final calls = <Map<String, dynamic>>[];
  Map<String, dynamic> record = {
    'id': '00000000-0000-4000-8000-000000000001',
    'title': 'AHU-01 · Supply air',
    'kind': 'duct',
    'project_id': null,
    'owner_name': 'Sarah Ahmed',
    'updated_by_name': 'Sarah Ahmed',
    'record_version': 2,
    'can_edit': true,
    'can_manage': true,
    'updated_at': '2026-10-06T08:00:00Z',
    'payload': {
      ...YorksCalculatorFiles.fresh('duct'),
      'flow': '2753',
      'width': '900',
      'height': '700',
    },
    'grants': <dynamic>[],
  };
  @override
  Future<Map<String, dynamic>> invoke({
    required String functionName,
    required Map<String, dynamic> parameters,
  }) async {
    calls.add({'function': functionName, ...parameters});
    if (fail != null) throw fail!;
    if (functionName == 'v1_list_calculators') {
      return {
        'items': [
          record,
          {
            ...record,
            'id': 'two',
            'title': 'AHU-02 · Pressure loss',
            'kind': 'esp',
            'project_name': 'NEXUS — Four substations',
          },
        ],
        'can_create': true,
        'can_manage': true,
      };
    }
    if (functionName == 'v1_calculator_options') {
      return {'projects': <dynamic>[], 'people': <dynamic>[]};
    }
    if (functionName == 'v1_save_calculator') {
      final intent = parameters['p_payload'] as Map;
      record = {
        ...record,
        'id': intent['id'],
        'title': intent['title'],
        'kind': intent['kind'],
        'payload': intent['payload'],
        'record_version': (intent['expected_version'] as int) + 1,
      };
    }
    return {...record};
  }
}

void main() {
  setUpAll(() async {
    final fonts = [
      FontLoader('NexusSans')
        ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf')),
      FontLoader('NotoSansArabic')
        ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf')),
    ];
    final root = File(Platform.resolvedExecutable).parent.parent.parent.parent;
    final icon = File(
      '${root.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    fonts.add(
      FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(await icon.readAsBytes()))),
    );
    await Future.wait(fonts.map((f) => f.load()));
  });
  test(
    'import preserves unknown fields and rejects wrong tool and malformed values',
    () {
      final data = {
        ...YorksCalculatorFiles.fresh('duct'),
        'future': {'nested': true},
      };
      expect(YorksCalculatorFiles.decode(jsonEncode(data))['future'], {
        'nested': true,
      });
      expect(
        () =>
            YorksCalculatorFiles.decode(jsonEncode(data), expectedKind: 'esp'),
        throwsFormatException,
      );
      expect(
        () => YorksCalculatorFiles.decode(jsonEncode({...data, 'flow': 'NaN'})),
        throwsFormatException,
      );
      expect(
        () => YorksCalculatorFiles.decode(
          jsonEncode({...data, 'material': 'unknown'}),
        ),
        throwsFormatException,
      );
      expect(
        () => YorksCalculatorFiles.decode(
          jsonEncode({
            'app': 'esp-calc',
            'version': 1,
            'rows': [null],
          }),
        ),
        throwsFormatException,
      );
      expect(
        () => YorksCalculatorFiles.decode('a' * 1048577),
        throwsFormatException,
      );
    },
  );
  test(
    'uncertain save persists and retries identical intent even if caller changes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final rpc = FakeCalculatorRpc()
        ..fail = TimeoutException('connection lost');
      final c = YorksCalculatorController(
        YorksCalculatorRepository(rpc),
        preferences: prefs,
        identity: 'backend|user|one',
      );
      final payload = {
        'id': 'one',
        'title': 'Original',
        'kind': 'duct',
        'expected_version': 0,
        'payload': YorksCalculatorFiles.fresh('duct'),
      };
      expect(await c.save(payload), isNull);
      expect(c.hasPending, isTrue);
      final next = YorksCalculatorController(
        YorksCalculatorRepository(rpc),
        preferences: prefs,
        identity: 'backend|user|one',
      );
      expect(next.recoverPending()?['title'], 'Original');
      final other = YorksCalculatorController(
        YorksCalculatorRepository(rpc),
        preferences: prefs,
        identity: 'backend|other|one',
      );
      expect(other.recoverPending(), isNull);
      rpc.fail = null;
      await next.save({...payload, 'title': 'Changed'});
      expect(rpc.calls.first['p_payload'], rpc.calls.last['p_payload']);
      expect(
        rpc.calls.first['p_idempotency_key'],
        rpc.calls.last['p_idempotency_key'],
      );
      expect(next.hasPending, isFalse);
      c.dispose();
      next.dispose();
      other.dispose();
    },
  );
  test(
    'revocation purges library and denies editor without replacing unsaved revision',
    () async {
      final rpc = FakeCalculatorRpc();
      final c = YorksCalculatorController(
        YorksCalculatorRepository(rpc),
        identity: 'test',
      );
      await c.open('one');
      rpc.record = {...rpc.record, 'record_version': 9, 'can_edit': false};
      await c.checkAccess();
      expect(c.record!.version, 2);
      expect(c.record!.canEdit, isFalse);
      rpc.fail = StateError('CALCULATOR_ACCESS_DENIED');
      await c.checkAccess();
      expect(c.denied, isTrue);
      await c.load();
      expect(c.items, isEmpty);
      expect(c.canCreate, isFalse);
      c.dispose();
    },
  );

  test(
    'save and reopen preserve inputs and names while new inputs stay empty',
    () async {
      final rpc = FakeCalculatorRpc();
      final c = YorksCalculatorController(
        YorksCalculatorRepository(rpc),
        identity: 'test',
      );
      await c.open('one');
      final result = await c.save({
        'id': c.record!.id,
        'title': 'Revised AHU',
        'kind': 'duct',
        'expected_version': 2,
        'payload': {...c.record!.payload, 'flow': '4567'},
      });
      expect(result!.version, 3);
      final reopened = YorksCalculatorController(
        YorksCalculatorRepository(rpc),
        identity: 'other-tab',
      );
      await reopened.open(result.id);
      expect(reopened.record!.title, 'Revised AHU');
      expect(reopened.record!.payload['flow'], '4567');
      expect(YorksCalculatorFiles.fresh('duct')['flow'], '');
      expect(YorksCalculatorFiles.fresh('esp')['rows'], isEmpty);
      c.dispose();
      reopened.dispose();
    },
  );
  test(
    'connection error does not masquerade as revoked access and clears after recovery',
    () async {
      final rpc = FakeCalculatorRpc();
      final c = YorksCalculatorController(
        YorksCalculatorRepository(rpc),
        identity: 'test',
      );
      await c.open('one');
      rpc.fail = TimeoutException('offline');
      await c.checkAccess();
      expect(c.denied, isFalse);
      expect(c.error, isNotNull);
      rpc.fail = null;
      await c.checkAccess();
      expect(c.error, isNull);
      c.dispose();
    },
  );
  test('filters reach repository before pagination', () async {
    final rpc = FakeCalculatorRpc();
    final c = YorksCalculatorController(
      YorksCalculatorRepository(rpc),
      identity: 'test',
    );
    c.kind = 'esp';
    c.scope = 'project';
    await c.load();
    expect(rpc.calls.last['p_kind'], 'esp');
    expect(rpc.calls.last['p_scope'], 'project');
    c.dispose();
  });
  testWidgets(
    'view only record disables title and save but retains print and export',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final rpc = FakeCalculatorRpc()
        ..record['can_edit'] = false
        ..record['can_manage'] = false;
      final c = YorksCalculatorController(
        YorksCalculatorRepository(rpc),
        identity: 'test',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            yorksCalculatorControllerProvider('one').overrideWithValue(c),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: YorksCalculatorWorkspace(recordId: 'one'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('View only'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).readOnly,
        isTrue,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNull,
      );
      expect(find.text('Print / PDF'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'legacy ESP row extensions survive missing identity and empty duplicate is safe',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final session = YorksCalculatorEditorSession(
        initialData: {
          ...YorksCalculatorFiles.fresh('esp'),
          'rows': [
            {
              'fitting': 'Straight Duct',
              'future': {'retain': true},
            },
          ],
        },
        onChanged: () {},
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(body: YorksV1EspCalculatorScreen(session: session)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final row = (session.snapshot!()['rows'] as List).single as Map;
      expect(row['future'], {'retain': true});
      expect(row['id'], isNotEmpty);
      await tester.pumpWidget(const SizedBox());
      final empty = YorksCalculatorEditorSession(
        initialData: YorksCalculatorFiles.fresh('esp'),
        onChanged: () {},
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(body: YorksV1EspCalculatorScreen(session: empty)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Duplicate Last'));
      await tester.tap(find.text('Duplicate Last'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(empty.snapshot!()['rows'], hasLength(1));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'new save returns to a refreshed home without reopening the old record',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final rpc = FakeCalculatorRpc();
      final router = GoRouter(
        initialLocation: yorksCalculatorsPath,
        routes: [
          GoRoute(
            path: yorksCalculatorsPath,
            builder: (context, state) =>
                const Scaffold(body: YorksCalculatorWorkspace()),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => Scaffold(
                  body: YorksCalculatorWorkspace(
                    recordId: state.pathParameters['id'],
                    initial: state.extra as Map<String, dynamic>?,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            yorksCalculatorControllerProvider.overrideWith((ref, key) {
              final c = YorksCalculatorController(
                YorksCalculatorRepository(rpc),
                identity: key,
              );
              ref.onDispose(c.dispose);
              return c;
            }),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New calculation').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField && w.decoration?.labelText == 'Calculation name',
        ),
        'New independent calculation',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create calculation'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Calculators').first);
      await tester.pumpAndSettle();
      expect(find.text('New independent calculation'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        yorksCalculatorsPath,
      );
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    },
  );
  for (final size in [
    const Size(1366, 900),
    const Size(768, 1024),
    const Size(360, 800),
  ]) {
    for (final screen in ['home', 'duct', 'esp']) {
      testWidgets('$screen responsive ${size.width}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final rpc = FakeCalculatorRpc();
        if (screen == 'esp') {
          rpc.record = {
            ...rpc.record,
            'kind': 'esp',
            'payload': {
              'app': 'esp-calc',
              'version': 1,
              'header': {'date': '06/10/2026'},
              'safetyFactor': '10',
              'rows': [
                {
                  'id': 'r1',
                  'fitting': 'Straight Duct',
                  'flow': '1000',
                  'width': '500',
                  'height': '300',
                  'length': '20',
                  'diameter': '',
                  'manualEsp': '',
                },
              ],
            },
          };
        }
        final c = YorksCalculatorController(
          YorksCalculatorRepository(rpc),
          identity: 'test',
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              yorksCalculatorControllerProvider(
                screen == 'home' ? 'library' : 'one',
              ).overrideWithValue(c),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: RepaintBoundary(
                  key: const Key('capture'),
                  child: YorksCalculatorWorkspace(
                    recordId: screen == 'home' ? null : 'one',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const Key('capture')),
          matchesGoldenFile(
            'goldens/calculators/${screen}_${size.width.toInt()}.png',
          ),
        );
        await tester.pumpWidget(const SizedBox());
        c.dispose();
      });
    }
  }
  testWidgets('Arabic library uses localized workspace labels', (tester) async {
    SharedPreferences.setMockInitialValues({
      'selected_language': AppLanguage.arabic.code,
    });
    final prefs = await SharedPreferences.getInstance();
    final c = YorksCalculatorController(
      YorksCalculatorRepository(FakeCalculatorRpc()),
      identity: 'test',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          yorksCalculatorControllerProvider('library').overrideWithValue(c),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: YorksCalculatorWorkspace()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('الحاسبات'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
