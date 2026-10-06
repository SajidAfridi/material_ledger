import 'package:material_ledger/app/yorks_v1_workspace_shell.dart';
import 'package:material_ledger/app/yorks_navigation_history.dart';
import 'package:material_ledger/shared/providers/yorks_v1_feature_flags_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'dart:async';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
// ignore: implementation_imports
import 'package:printing/src/interface.dart';
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
import 'package:material_ledger/features/engineering_tools/presentation/widgets/yorks_calculator_controls.dart';

class FakeCalculatorRpc implements YorksV1ProjectRpcClient {
  Completer<void>? saveGate;
  Completer<void>? manageGate;
  Object? manageFailure;
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
      await saveGate?.future;
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
    if (functionName == 'v1_manage_calculator') {
      await manageGate?.future;
      if (manageFailure != null) throw manageFailure!;
      final intent = parameters['p_payload'] as Map;
      record = {
        ...record,
        'record_version': (intent['expected_version'] as int) + 1,
        'grants': [
          for (final grant in record['grants'] as List)
            if (grant['user_id'] != intent['user_id'])
              grant
            else if (intent['access'] != 'none')
              {...grant as Map, 'access': intent['access']},
        ],
      };
    }
    return {...record};
  }
}

class CaptureCalculatorPrinting extends PrintingPlatform {
  Uint8List? bytes;
  @override
  Future<bool> layoutPdf(
    Printer? printer,
    LayoutCallback onLayout,
    String name,
    PdfPageFormat format,
    bool dynamicLayout,
    bool usePrinterSettings,
    OutputType outputType,
    bool forceCustomPrintPaper,
    bool windowsModernDialog,
  ) async {
    bytes = await onLayout(format);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<YorksCalculatorController> pumpPolishRecord(
  WidgetTester tester,
  FakeCalculatorRpc rpc,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = YorksCalculatorController(
    YorksCalculatorRepository(rpc),
    identity: 'polish',
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        yorksCalculatorControllerProvider('one').overrideWithValue(c),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: const Scaffold(body: YorksCalculatorWorkspace(recordId: 'one')),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

Future<void> calculatorShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
  bool alt = false,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(key);
  if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
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
    'project archive rejects save without retaining a retry or changing inputs',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final rpc = FakeCalculatorRpc();
      rpc.record['project_id'] = '00000000-0000-4000-8000-000000000002';
      final c = YorksCalculatorController(
        YorksCalculatorRepository(rpc),
        preferences: prefs,
        identity: 'archive-regression',
      );
      await c.open('one');
      rpc.fail = StateError('CALCULATOR_PROJECT_ARCHIVED');
      expect(
        await c.save({
          'id': c.record!.id,
          'project_id': c.record!.projectId,
          'expected_version': 2,
          'title': 'Unsaved change',
          'kind': 'duct',
          'payload': {...c.record!.payload, 'flow': '3000'},
        }),
        isNull,
      );
      expect(c.hasPending, isFalse);
      expect(c.recoverPending(), isNull);
      expect(c.denied, isFalse); // Read/export access is retained.
      expect(c.record!.canEdit, isFalse);
      expect(c.record!.version, 2);
      expect(c.record!.payload['flow'], '2753');
      expect(c.error.toString(), contains('CALCULATOR_PROJECT_ARCHIVED'));
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
            debugShowCheckedModeBanner: false,
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
      await tester.tap(find.byTooltip('Export'));
      await tester.pumpAndSettle();
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
            debugShowCheckedModeBanner: false,
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
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: YorksV1EspCalculatorScreen(session: empty)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Duplicate row'));
      await tester.tap(find.text('Duplicate row'));
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
            debugShowCheckedModeBanner: false,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New calculation').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Calculation name',
        ),
        'New independent calculation',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create calculation'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Calculators'), findsNothing);
      router.pop();
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
  testWidgets(
    'Arabic calculator editor preserves RTL and translated input labels at 360px',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'selected_language': AppLanguage.arabic.code,
      });
      final prefs = await SharedPreferences.getInstance();
      final c = YorksCalculatorController(
        YorksCalculatorRepository(FakeCalculatorRpc()),
        identity: 'rtl',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            yorksCalculatorControllerProvider('one').overrideWithValue(c),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(body: YorksCalculatorWorkspace(recordId: 'one')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('معايير التصميم'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'معدل التدفق',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'compact record menu keeps viewer outputs and edit permissions distinct',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final rpc = FakeCalculatorRpc()
        ..record['can_edit'] = false
        ..record['can_manage'] = false;
      final c = YorksCalculatorController(
        YorksCalculatorRepository(rpc),
        identity: 'viewer',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            yorksCalculatorControllerProvider('one').overrideWithValue(c),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            home: const Scaffold(
              body: YorksCalculatorWorkspace(recordId: 'one'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Files'));
      await tester.pumpAndSettle();
      expect(find.text('Print / PDF'), findsOneWidget);
      expect(find.text('Export JSON'), findsOneWidget);
      expect(
        tester
            .widget<PopupMenuItem<String>>(
              find.widgetWithText(PopupMenuItem<String>, 'Import JSON'),
            )
            .enabled,
        isFalse,
      );
      expect(find.text('Archive'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'saved record enables Save only after a change and resets after undo',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = YorksCalculatorController(
        YorksCalculatorRepository(FakeCalculatorRpc()),
        identity: 'save',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            yorksCalculatorControllerProvider('one').overrideWithValue(c),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            home: const Scaffold(
              body: YorksCalculatorWorkspace(recordId: 'one'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.enterText(find.byType(TextField).first, 'Changed');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await tester.enterText(
        find.byType(TextField).first,
        'AHU-01 · Supply air',
      );
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets('in-flight save shows progress until server confirmation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final rpc = FakeCalculatorRpc()..saveGate = Completer<void>();
    final c = YorksCalculatorController(
      YorksCalculatorRepository(rpc),
      identity: 'in-flight',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          yorksCalculatorControllerProvider('one').overrideWithValue(c),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          home: const Scaffold(body: YorksCalculatorWorkspace(recordId: 'one')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'Saved after confirmation',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    expect(find.text('Saving…'), findsNWidgets(2));
    expect(
      find.text('Save not confirmed. Retry to confirm the same changes.'),
      findsNothing,
    );
    rpc.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('collapsible design basis preserves edits and selected method', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final session = YorksCalculatorEditorSession(
      initialData: {
        ...YorksCalculatorFiles.fresh('duct'),
        'flow': '1000',
        'width': '500',
        'height': '300',
      },
      onChanged: () {},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: YorksV1DuctSizerScreen(session: session)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final flow = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Flow Rate',
    );
    await tester.enterText(flow, '1234');
    await tester.pumpAndSettle();
    final before = session.snapshot!();
    await tester.ensureVisible(find.text('Design basis'));
    await tester.tap(find.text('Design basis'));
    await tester.pumpAndSettle();
    expect(
      YorksCalculatorFiles.fingerprint(
        Map<String, dynamic>.from(session.snapshot!()),
      ),
      YorksCalculatorFiles.fingerprint(Map<String, dynamic>.from(before)),
    );
    expect(find.text('DENSITY'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'calculator undo and redo shortcuts restore inputs while a field has focus',
    (tester) async {
      final c = await pumpPolishRecord(tester, FakeCalculatorRpc());
      final flow = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Flow Rate',
      );
      await tester.enterText(flow, '4200');
      await tester.pumpAndSettle();
      await calculatorShortcut(tester, LogicalKeyboardKey.keyZ);
      expect(tester.widget<TextField>(flow).controller!.text, '2753');
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNull,
      );
      await calculatorShortcut(tester, LogicalKeyboardKey.keyZ, shift: true);
      expect(tester.widget<TextField>(flow).controller!.text, '4200');
      expect(find.widgetWithText(TextButton, 'Calculators'), findsNothing);
      await tester.tap(find.byTooltip('Undo (Ctrl+Z)'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(flow).controller!.text, '2753');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'row keyboard actions duplicate active data and history restores row identities and extensions',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final rpc = FakeCalculatorRpc()
        ..record['kind'] = 'esp'
        ..record['payload'] = {
          ...YorksCalculatorFiles.fresh('esp'),
          'rows': [
            {
              'id': 'first',
              'fitting': 'Straight Duct',
              'flow': '1100',
              'width': '500',
              'height': '300',
              'length': '5',
              'future': {'keep': true},
            },
            {
              'id': 'second',
              'fitting': 'Straight Duct',
              'flow': '2200',
              'width': '800',
              'height': '400',
              'length': '8',
            },
          ],
        };
      final c = await pumpPolishRecord(tester, rpc);
      final session = tester
          .widget<YorksV1EspCalculatorScreen>(
            find.byType(YorksV1EspCalculatorScreen),
          )
          .session!;
      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == '1100',
      );
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      await calculatorShortcut(tester, LogicalKeyboardKey.enter, alt: true);
      var rows = session.snapshot!()['rows'] as List;
      expect(rows, hasLength(3));
      expect(rows[1]['flow'], '1100');
      expect(rows[1]['future'], {'keep': true});
      expect(rows[2]['id'], 'second');
      final duplicateId = rows[1]['id'];
      await calculatorShortcut(tester, LogicalKeyboardKey.keyZ);
      rows = session.snapshot!()['rows'] as List;
      expect(rows.map((r) => r['id']), ['first', 'second']);
      await calculatorShortcut(tester, LogicalKeyboardKey.keyZ, shift: true);
      rows = session.snapshot!()['rows'] as List;
      expect(rows[1]['id'], duplicateId);
      expect(rows[1]['future'], {'keep': true});
      await calculatorShortcut(tester, LogicalKeyboardKey.enter, shift: true);
      expect(session.snapshot!()['rows'], hasLength(4));
      expect(find.text('Ctrl+Shift+Enter'), findsOneWidget);
      expect(find.text('Ctrl+Alt+Enter'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets('viewer keyboard shortcuts cannot mutate or save inputs', (
    tester,
  ) async {
    final rpc = FakeCalculatorRpc()
      ..record['can_edit'] = false
      ..record['can_manage'] = false;
    final c = await pumpPolishRecord(tester, rpc);
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await calculatorShortcut(tester, LogicalKeyboardKey.keyZ);
    await calculatorShortcut(tester, LogicalKeyboardKey.keyS);
    expect(
      rpc.calls.where((r) => r['function'] == 'v1_save_calculator'),
      isEmpty,
    );
    expect(find.byTooltip('Undo (Ctrl+Z)'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Undo (Ctrl+Z)',
            ),
          )
          .onPressed,
      isNull,
    );
    expect(find.byTooltip('Manage access'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  for (final width in [1366.0, 360.0]) {
    for (final confirmed in ['edit', 'view']) {
      testWidgets(
        'rejected access change restores confirmed $confirmed and permits retry at $width',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final rpc = FakeCalculatorRpc()
            ..record['grants'] = [
              {
                'user_id': 'shared',
                'name': 'Shared engineer',
                'access': confirmed,
              },
            ];
          final c = await pumpPolishRecord(tester, rpc);
          await tester.tap(
            width < 720
                ? find.widgetWithText(TextButton, 'Manage access')
                : find.byTooltip('Manage access'),
          );
          await tester.pumpAndSettle();
          final grantPicker = find
              .descendant(
                of: find.byType(Dialog),
                matching: find.byType(YorksCalculatorSelect<String>),
              )
              .first;
          final grantField = find.descendant(
            of: grantPicker,
            matching: find.byType(TextField),
          );
          final desired = confirmed == 'edit' ? 'view' : 'edit';
          final desiredLabel = desired == 'view' ? 'Can view' : 'Can edit';
          final confirmedLabel = confirmed == 'edit' ? 'Can edit' : 'Can view';
          Future<void> selectDesired() async {
            await tester.tap(
              find
                  .descendant(
                    of: grantPicker,
                    matching: find.byType(IconButton),
                  )
                  .first,
            );
            await tester.pumpAndSettle();
            await tester.tap(
              find.widgetWithText(MenuItemButton, desiredLabel).hitTestable(),
            );
          }

          rpc.manageGate = Completer<void>();
          rpc.manageFailure = StateError('CALCULATOR_VERSION_CONFLICT');
          await selectDesired();
          await tester.pump();
          await tester.pump();
          expect(c.busy, isTrue);
          expect(
            tester
                .widget<YorksCalculatorSelect<String>>(grantPicker)
                .onSelected,
            isNull,
          );
          rpc.manageGate!.complete();
          await tester.pumpAndSettle();
          expect(c.record!.grants.single['access'], confirmed);
          expect(c.record!.version, 2);
          expect(
            tester.widget<TextField>(grantField).controller!.text,
            confirmedLabel,
          );
          expect(find.text('Access updated'), findsNothing);
          expect(c.error, isNotNull);
          if (confirmed == 'edit') {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                'goldens/calculators/access_rejected_${width.toInt()}.png',
              ),
            );
          }

          rpc.manageGate = null;
          rpc.manageFailure = null;
          await selectDesired();
          await tester.pumpAndSettle();
          expect(c.record!.grants.single['access'], desired);
          expect(c.record!.version, 3);
          expect(
            tester.widget<TextField>(grantField).controller!.text,
            desiredLabel,
          );
          expect(
            rpc.calls.where(
              (call) => call['function'] == 'v1_manage_calculator',
            ),
            hasLength(2),
          );
          expect(c.error, isNull);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          c.dispose();
        },
      );
    }
  }

  testWidgets(
    'rapid delete and clear each preserve a separate undo and redo step',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final original = [
        for (final id in ['first', 'second', 'third'])
          {
            'id': id,
            'fitting': 'Straight Duct',
            'flow': '1100',
            'future': {'retained': id},
          },
      ];
      final rpc = FakeCalculatorRpc()
        ..record['kind'] = 'esp'
        ..record['payload'] = {
          ...YorksCalculatorFiles.fresh('esp'),
          'rows': original,
        };
      final c = await pumpPolishRecord(tester, rpc);
      final session = tester
          .widget<YorksV1EspCalculatorScreen>(
            find.byType(YorksV1EspCalculatorScreen),
          )
          .session!;
      List rows() => session.snapshot!()['rows'] as List;
      void expectRows(List<String> ids) {
        expect(rows().map((r) => r['id']), ids);
        for (final row in rows()) {
          expect(row['future'], {'retained': row['id']});
        }
      }

      Future<void> deleteFirst() async {
        final button = find.byTooltip('Delete row').first;
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
      }

      await deleteFirst();
      expectRows(['second', 'third']);
      await deleteFirst();
      expectRows(['third']);
      await tester.ensureVisible(find.text('Clear'));
      await tester.tap(find.text('Clear'));
      await tester.pump();
      expectRows([]);
      Future<void> history({bool redo = false}) async {
        final button = find.byTooltip(
          redo ? 'Redo (Ctrl+Shift+Z)' : 'Undo (Ctrl+Z)',
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      await history();
      expectRows(['third']);
      await history();
      expectRows(['second', 'third']);
      await history();
      expectRows(['first', 'second', 'third']);
      await history(redo: true);
      expectRows(['second', 'third']);
      await history(redo: true);
      expectRows(['third']);
      await history(redo: true);
      expectRows([]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'missing device calculations explain the browser boundary instead of invalid file',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = YorksCalculatorController(
        YorksCalculatorRepository(FakeCalculatorRpc()),
        identity: 'library',
        preferences: prefs,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            yorksCalculatorControllerProvider('library').overrideWithValue(c),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            home: const Scaffold(body: YorksCalculatorWorkspace()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Import JSON'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import previous device calculation'));
      await tester.pumpAndSettle();
      expect(
        find.text('No previous calculations on this device'),
        findsOneWidget,
      );
      expect(find.text('No saved calculation'), findsNWidgets(2));
      expect(find.byType(SnackBar), findsNothing);
      expect(prefs.getKeys(), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'invalid device data stays preserved and is distinguished from absence',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'yorks_r35_duct_calculation': 'not-json',
      });
      final prefs = await SharedPreferences.getInstance();
      final c = YorksCalculatorController(
        YorksCalculatorRepository(FakeCalculatorRpc()),
        identity: 'library',
        preferences: prefs,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            yorksCalculatorControllerProvider('library').overrideWithValue(c),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            home: const Scaffold(body: YorksCalculatorWorkspace()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Import JSON'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import previous device calculation'));
      await tester.pumpAndSettle();
      expect(find.text('Saved data needs a valid JSON file'), findsOneWidget);
      expect(prefs.getString('yorks_r35_duct_calculation'), 'not-json');
      expect(find.byType(SnackBar), findsNothing);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  for (final width in [1366.0, 360.0]) {
    testWidgets('creation dialog is clean and keyboard operable at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = YorksCalculatorController(
        YorksCalculatorRepository(FakeCalculatorRpc()),
        identity: 'dialog',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            yorksCalculatorControllerProvider('library').overrideWithValue(c),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            home: const Scaffold(body: YorksCalculatorWorkspace()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New calculation').first);
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<String>), findsOneWidget);
      expect(find.text('Calculator type'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/calculators/create_${width.toInt()}.png'),
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
    testWidgets('access dialog follows the shared controls at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = await pumpPolishRecord(tester, FakeCalculatorRpc());
      await tester.tap(
        width < 720
            ? find.widgetWithText(TextButton, 'Manage access')
            : find.byTooltip('Manage access'),
      );
      await tester.pumpAndSettle();
      expect(find.text('People with access'), findsOneWidget);
      expect(find.text('Grant access'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/calculators/access_${width.toInt()}.png'),
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }

  testWidgets(
    'shared top-bar Back prompts once and preserves history when editing continues',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final rpc = FakeCalculatorRpc();
      final router = GoRouter(
        initialLocation: yorksCalculatorsPath,
        routes: [
          GoRoute(
            path: yorksCalculatorsPath,
            builder: (context, state) =>
                const YorksV1WorkspaceShell(child: Text('Library content')),
            routes: [
              GoRoute(
                path: ':id',
                onExit: (context, state) =>
                    ProviderScope.containerOf(
                      context,
                      listen: false,
                    ).read(yorksCalculatorExitGuardProvider).check?.call() ??
                    true,
                builder: (context, state) => YorksV1WorkspaceShell(
                  child: YorksCalculatorWorkspace(
                    recordId: state.pathParameters['id'],
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
            yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.admin),
            yorksCalculatorWorkspaceEnabledProvider.overrideWithValue(true),
            yorksV1FeatureFlagsProvider.overrideWithValue(
              const YorksV1FeatureFlags(
                foundation: true,
                projects: true,
                boq: true,
                excel: true,
                requests: true,
                arrangement: true,
                logistics: true,
                returnsDocuments: true,
                documents: true,
              ),
            ),
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
            debugShowCheckedModeBanner: false,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      router.go('$yorksCalculatorsPath/one');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Calculation name',
        ),
        'Changed title',
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(YorksCalculatorWorkspace)),
      );
      final historyBefore = container
          .read(yorksNavigationHistoryProvider)
          .cursor;
      await tester.tap(find.byTooltip('Back').first);
      await tester.pumpAndSettle();
      expect(find.text('Leave without saving?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '$yorksCalculatorsPath/one',
      );
      expect(
        container.read(yorksNavigationHistoryProvider).cursor,
        historyBefore,
      );
      await tester.tap(find.byTooltip('Back').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        yorksCalculatorsPath,
      );
      expect(find.text('Leave without saving?'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    },
  );

  testWidgets(
    'print handles Unicode metadata and a full 1000-row ESP calculation',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final previous = PrintingPlatform.instance;
      final printer = CaptureCalculatorPrinting();
      PrintingPlatform.instance = printer;
      addTearDown(() => PrintingPlatform.instance = previous);
      for (final kind in ['duct', 'esp']) {
        final data = kind == 'duct'
            ? {
                ...YorksCalculatorFiles.fresh(kind),
                'flow': '1000',
                'width': '500',
                'height': '300',
              }
            : {
                ...YorksCalculatorFiles.fresh(kind),
                'header': {
                  'systemNo': 'AHU-02',
                  'equipment': 'Fan 1',
                  'projectName': 'NEXUS',
                },
                'rows': [
                  for (var i = 0; i < 1000; i++)
                    {
                      'id': 'pdf-$i',
                      'fitting': 'Straight Duct',
                      'flow': '1000',
                      'width': '500',
                      'height': '300',
                      'length': '2',
                    },
                ],
              };
        final session =
            YorksCalculatorEditorSession(initialData: data, onChanged: () {})
              ..title = 'AHU-01 · اختبار'
              ..scope = 'NEXUS'
              ..revision = 'Revision 1';
        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp(
              theme: AppTheme.light,
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: kind == 'duct'
                    ? YorksV1DuctSizerScreen(session: session)
                    : YorksV1EspCalculatorScreen(session: session),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() => session.printFile!.call());
        expect(printer.bytes, isNotNull);
        expect(ascii.decode(printer.bytes!.take(5).toList()), '%PDF-');
        expect(
          printer.bytes!.length,
          greaterThan(kind == 'esp' ? 50000 : 5000),
        );
        const directory = String.fromEnvironment('CALCULATOR_PDF_EVIDENCE');
        if (directory.isNotEmpty) {
          await tester.runAsync(() async {
            await Directory(directory).create(recursive: true);
            await File('$directory/$kind.pdf').writeAsBytes(printer.bytes!);
          });
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
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
              debugShowCheckedModeBanner: false,
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
          debugShowCheckedModeBanner: false,
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
