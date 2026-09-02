import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ledger/app/router.dart';
import 'package:material_ledger/app/yorks_v1_workspace_shell.dart';
import 'package:material_ledger/core/constants/constants.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_material_request_screens.dart';
import 'package:material_ledger/shared/models/app_language.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request_document.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request_strings.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/models/yorks_v1_boq.dart';
import 'package:material_ledger/shared/models/yorks_v1_boq_workbook.dart';
import 'package:material_ledger/shared/models/yorks_v1_configuration.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_boq_repository_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_configuration_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_material_request_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_material_request_repository_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_permission_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_workspace_presentation_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_boq_repository.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_material_request_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/yorks_v1_permission_test_support.dart';

const _draftId = 'mobile-mr-draft';
const _projectId = 'mobile-mr-project';
const _alternateProjectId = 'mobile-mr-project-nexus';
const _draftProjects = [
  YorksV1MaterialRequestProjectOption(
    id: _projectId,
    reference: 'YRA-322',
    name: 'Al Dhafra Grid Substation HVAC Works',
    state: 'active',
  ),
  YorksV1MaterialRequestProjectOption(
    id: _alternateProjectId,
    reference: 'YRA-315',
    name: 'Nexus 4 Station',
    state: 'active',
  ),
];
late SharedPreferences _preferences;

void main() {
  setUpAll(() async {
    final nexusFontLoader = FontLoader('NexusSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final arabicFontLoader = FontLoader('NotoSansArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
    final flutterCache = _flutterCacheDirectory();
    final iconBytes = await File(
      '${flutterCache.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes();
    final iconFontLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(iconBytes)));
    await Future.wait([
      nexusFontLoader.load(),
      arabicFontLoader.load(),
      iconFontLoader.load(),
    ]);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _preferences = await SharedPreferences.getInstance();
  });

  testWidgets('desktop MR draft keeps compact source and row actions', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    await _pumpDraft(tester, boqRepository: _DesktopBoqRepositoryFixture());

    expect(find.text('Add Custom Item'), findsOneWidget);
    expect(find.text('Add from BOQ'), findsOneWidget);
    expect(find.text('Import Excel'), findsOneWidget);
    expect(find.text('Row tools'), findsNothing);
    expect(find.text('Add Blank Row'), findsNothing);
    expect(find.text('Add Similar Row'), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/r35/mr_draft_boq_actions_desktop.png'),
    );
  });

  testWidgets('desktop custom item action waits for project selection', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    await _pumpDraft(tester, initialProjectId: null);

    final addCustom = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Add Custom Item'),
    );
    expect(addCustom.onPressed, isNull);
    expect(
      find.text('Choose a project before adding material items.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop custom-row shortcut follows familiar Ctrl Shift C', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    await _pumpDraft(tester);
    await tester.tap(find.byKey(const ValueKey('mr-title')));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Add Similar Row'), findsOneWidget);
    expect(find.byTooltip('Add custom row here'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop draft starts in focused mode and keeps request context optional',
    (tester) async {
      await _setViewport(tester, const Size(1366, 768));
      await _pumpDraft(tester);

      final scope = ProviderScope.containerOf(
        tester.element(find.byType(YorksV1MaterialRequestDraftScreen)),
      );
      expect(scope.read(yorksV1WorkspaceSidebarExpandedProvider), isFalse);
      expect(
        find.byKey(const ValueKey('mr-request-context-panel')),
        findsNothing,
      );
      expect(find.text('Delivery note (optional)'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('mr-request-context-toggle')));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('mr-request-context-panel')),
        findsOneWidget,
      );
      expect(find.text('Request Status'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      final description = find.byKey(
        const ValueKey('mr-material-description-autocomplete'),
      );
      expect(
        find.descendant(
          of: description,
          matching: find.byIcon(Icons.search_rounded),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'published timing policy defaults a pristine desktop draft and hides disabled urgent',
    (tester) async {
      await _setViewport(tester, const Size(1366, 768));
      await _pumpDraft(
        tester,
        runtimeConfiguration: _runtimeConfiguration(
          defaultTiming: 'scheduled',
          urgentEnabled: false,
        ),
      );

      final timingPicker = tester
          .widget<DropdownButton<YorksV1MaterialRequestTiming>>(
            find.descendant(
              of: find.byKey(const ValueKey('mr-timing-picker')),
              matching: find.byType(
                DropdownButton<YorksV1MaterialRequestTiming>,
              ),
            ),
          );
      expect(
        timingPicker.items?.map((item) => item.value),
        orderedEquals(const [
          YorksV1MaterialRequestTiming.normal,
          YorksV1MaterialRequestTiming.scheduled,
        ]),
      );
      expect(find.text('Scheduled date'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile timing policy fails closed when urgent is disabled', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    await _pumpDraft(
      tester,
      runtimeConfiguration: _runtimeConfiguration(urgentEnabled: false),
    );

    expect(find.text('Urgent'), findsNothing);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Scheduled'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an existing urgent draft remains visible when urgent is off', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    await _pumpDraft(
      tester,
      runtimeConfiguration: _runtimeConfiguration(urgentEnabled: false),
      serverRequest: _urgentDraftRequest,
    );

    final timingPicker = tester
        .widget<DropdownButton<YorksV1MaterialRequestTiming>>(
          find.descendant(
            of: find.byKey(const ValueKey('mr-timing-picker')),
            matching: find.byType(DropdownButton<YorksV1MaterialRequestTiming>),
          ),
        );
    expect(
      timingPicker.items?.map((item) => item.value),
      contains(YorksV1MaterialRequestTiming.urgent),
    );
    expect(find.text('Urgent'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop MR row exposes Similar, Custom and delete', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    await _pumpDraft(tester);

    await tester.tap(find.text('Add Custom Item'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Add Similar Row'), findsOneWidget);
    expect(find.byTooltip('Add custom row here'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Add custom row here'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add custom row here').hitTestable());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Add Similar Row'), findsNWidgets(2));
    expect(find.byTooltip('Add custom row here'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop incomplete rows keep a stable height with semantic error dots',
    (tester) async {
      await _setViewport(tester, const Size(1366, 768));
      await _pumpDraft(tester);

      await tester.tap(find.text('Add Custom Item'));
      await tester.pumpAndSettle();

      final scope = ProviderScope.containerOf(
        tester.element(find.byType(YorksV1MaterialRequestDraftScreen)),
      );
      final controller = scope.read(
        yorksV1MaterialRequestDraftControllerProvider(
          const YorksV1MaterialRequestDraftKey(
            ownerAuthUserId: 'mobile-mr-user',
            draftId: _draftId,
          ),
        ).notifier,
      );
      final line = controller.currentDraft.lines.single;
      final table = find.byType(Table).last;
      final invalidHeight = tester.getSize(table).height;

      expect(find.text('Item description is required'), findsNothing);
      expect(find.text('Enter a quantity greater than zero'), findsNothing);
      expect(find.text('Select a valid unit'), findsNothing);
      expect(
        find.byKey(ValueKey('${line.id}-description-error')),
        findsOneWidget,
      );
      expect(find.byKey(ValueKey('${line.id}-quantity-error')), findsOneWidget);
      expect(find.byKey(ValueKey('${line.id}-unit-error')), findsOneWidget);
      expect(
        find.bySemanticsLabel('Item description is required'),
        findsOneWidget,
      );
      expect(
        find.textContaining('1 material row needs attention'),
        findsOneWidget,
      );

      await controller.updateLine(
        line.id,
        (current) => current.copyWith(
          description: 'Access door',
          quantity: '10',
          unit: 'Nos',
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(table).height, invalidHeight);
      expect(
        find.byKey(ValueKey('${line.id}-description-error')),
        findsNothing,
      );
      expect(find.byKey(ValueKey('${line.id}-quantity-error')), findsNothing);
      expect(find.byKey(ValueKey('${line.id}-unit-error')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'project picker opens all projects, filters, and commits only a selection',
    (tester) async {
      await _setViewport(tester, const Size(1366, 768));
      await _pumpDraft(tester, projectOptions: _draftProjects);

      final picker = find.byKey(const ValueKey('mr-project'));
      await tester.tap(picker);
      await tester.pump();

      final panel = find.byKey(const ValueKey('mr-project-suggestion-panel'));
      expect(panel, findsOneWidget);
      expect(
        find.descendant(
          of: panel,
          matching: find.text('Al Dhafra Grid Substation HVAC Works'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: panel, matching: find.text('Nexus 4 Station')),
        findsOneWidget,
      );

      await tester.enterText(picker, 'yra315');
      await tester.pump();
      expect(
        find.descendant(of: panel, matching: find.text('Nexus 4 Station')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: panel,
          matching: find.text('Al Dhafra Grid Substation HVAC Works'),
        ),
        findsNothing,
      );

      await tester.enterText(picker, 'nexus station');
      await tester.pump();

      expect(
        find.descendant(of: panel, matching: find.text('Nexus 4 Station')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: panel,
          matching: find.text('Al Dhafra Grid Substation HVAC Works'),
        ),
        findsNothing,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/r35/mr_project_picker_desktop.png'),
      );
      await tester.tap(
        find.descendant(of: panel, matching: find.text('Nexus 4 Station')),
      );
      await tester.pumpAndSettle();

      final scope = ProviderScope.containerOf(
        tester.element(find.byType(YorksV1MaterialRequestDraftScreen)),
      );
      final draft = scope.read(
        yorksV1MaterialRequestDraftControllerProvider(
          const YorksV1MaterialRequestDraftKey(
            ownerAuthUserId: 'mobile-mr-user',
            draftId: _draftId,
          ),
        ),
      );
      expect(draft.draft.projectId, _alternateProjectId);
      final field = tester.widget<TextFormField>(picker);
      expect(field.controller?.text, 'YRA-315 · Nexus 4 Station');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('phone project search and material actions stay touch safe', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 800));
    await _pumpDraft(tester, projectOptions: _draftProjects);

    final picker = find.byKey(const ValueKey('mobile-mr-project'));
    expect(tester.getSize(picker).height, greaterThanOrEqualTo(44));
    await tester.tap(picker);
    await tester.pump();

    final panel = find.byKey(const ValueKey('mr-project-suggestion-panel'));
    expect(panel, findsOneWidget);
    final panelRect = tester.getRect(panel);
    expect(panelRect.left, greaterThanOrEqualTo(16));
    expect(panelRect.right, lessThanOrEqualTo(344));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(panel, findsNothing);
    expect(
      tester.widget<TextFormField>(picker).controller?.text,
      'YRA-322 · Al Dhafra Grid Substation HVAC Works',
    );

    final scope = ProviderScope.containerOf(
      tester.element(find.byType(YorksV1MaterialRequestDraftScreen)),
    );
    final controller = scope.read(
      yorksV1MaterialRequestDraftControllerProvider(
        const YorksV1MaterialRequestDraftKey(
          ownerAuthUserId: 'mobile-mr-user',
          draftId: _draftId,
        ),
      ).notifier,
    );
    await controller.addCustomLine();
    final line = controller.currentDraft.lines.single;
    await controller.updateLine(
      line.id,
      (current) => current.copyWith(
        description: 'Access door',
        quantity: '10',
        unit: 'Nos',
      ),
    );
    await tester.pumpAndSettle();
    await _continueToMaterials(tester);

    for (final suffix in ['edit', 'similar', 'custom', 'delete']) {
      final action = find.byKey(ValueKey('${line.id}-mobile-$suffix'));
      expect(action, findsOneWidget);
      expect(tester.getSize(action).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mobile selected material opens its focused editor and updates in place',
    (tester) async {
      await _setViewport(tester, const Size(390, 844));
      await _pumpDraft(tester);
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(YorksV1MaterialRequestDraftScreen)),
      );
      final controller = scope.read(
        yorksV1MaterialRequestDraftControllerProvider(
          const YorksV1MaterialRequestDraftKey(
            ownerAuthUserId: 'mobile-mr-user',
            draftId: _draftId,
          ),
        ).notifier,
      );
      await controller.addCustomLine();
      final original = controller.currentDraft.lines.single;
      await controller.updateLine(
        original.id,
        (current) => current.copyWith(
          description: 'Access door',
          brandOrigin: 'Beta UAE',
          size: '100x100',
          model: 'AD-100',
          quantity: '11',
          unit: 'Nos',
        ),
      );
      await tester.pumpAndSettle();
      await _continueToMaterials(tester);

      final cardBody = find.text('Access door');
      expect(cardBody, findsOneWidget);
      await tester.tap(cardBody);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('mobile-mr-custom-material')),
        findsOneWidget,
      );
      expect(find.text('Edit Material'), findsWidgets);
      final descriptionField = find.descendant(
        of: find.byKey(const ValueKey('mobile-custom-description')),
        matching: find.byType(TextFormField),
      );
      final quantityField = find.byKey(
        const ValueKey('mobile-custom-quantity'),
      );
      expect(
        tester.widget<TextFormField>(descriptionField).controller?.text,
        'Access door',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('mobile-custom-brand')),
            )
            .controller
            ?.text,
        'Beta UAE',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('mobile-custom-size')),
            )
            .controller
            ?.text,
        '100x100',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('mobile-custom-model')),
            )
            .controller
            ?.text,
        'AD-100',
      );
      expect(
        tester.widget<TextFormField>(quantityField).controller?.text,
        '11',
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/r35/mr_edit_existing_mobile_390x844.png'),
      );

      await tester.enterText(descriptionField, 'Access door revised');
      await tester.enterText(quantityField, '12.5');
      await tester.tap(find.text('Save Changes').hitTestable());
      await tester.pumpAndSettle();

      final updated = controller.currentDraft.lines.single;
      expect(updated.id, original.id);
      expect(updated.description, 'Access door revised');
      expect(updated.quantity, '12.5');
      expect(updated.brandOrigin, 'Beta UAE');
      expect(updated.size, '100x100');
      expect(updated.model, 'AD-100');
      expect(updated.unit, 'Nos');
      expect(find.text('Access door revised'), findsOneWidget);

      await tester.tap(
        find.byKey(ValueKey('${original.id}-mobile-edit')).hitTestable(),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Not committed');
      await tester.tap(find.text('Back').hitTestable());
      await tester.pumpAndSettle();

      expect(controller.currentDraft.lines, hasLength(1));
      expect(controller.currentDraft.lines.single.id, original.id);
      expect(
        controller.currentDraft.lines.single.description,
        'Access door revised',
      );
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tablet uses focused rows and compact validation markers', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1024, 768));
    await _pumpDraft(tester);
    final scope = ProviderScope.containerOf(
      tester.element(find.byType(YorksV1MaterialRequestDraftScreen)),
    );
    final controller = scope.read(
      yorksV1MaterialRequestDraftControllerProvider(
        const YorksV1MaterialRequestDraftKey(
          ownerAuthUserId: 'mobile-mr-user',
          draftId: _draftId,
        ),
      ).notifier,
    );
    await controller.addCustomLine();
    await tester.pumpAndSettle();
    final line = controller.currentDraft.lines.single;

    expect(find.byKey(const ValueKey('mr-project')), findsOneWidget);
    expect(
      find.byKey(ValueKey('${line.id}-focused-description-error')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('${line.id}-focused-quantity-error')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('${line.id}-focused-unit-error')),
      findsOneWidget,
    );
    expect(find.text('Item description is required'), findsNothing);
    expect(find.byKey(ValueKey('${line.id}-focused-delete')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet request information keeps a balanced workspace', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1024, 768));
    await _pumpDraft(tester);

    expect(find.byKey(const ValueKey('mr-project')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-mr-information')), findsNothing);
    expect(find.text('Request Information'), findsWidgets);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/r35/mr_information_tablet_1024x768.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop description typing ranks BOQ before inventory and fills descriptive cells',
    (tester) async {
      await _setViewport(tester, const Size(1366, 768));
      final repository = await _pumpDraft(tester);
      repository.inventorySuggestions = const [
        YorksV1MaterialRequestInventorySuggestion(
          id: 'boq-row-duct',
          source: YorksV1MaterialRequestSuggestionSource.selectedScopeBoq,
          description: 'Flexible duct',
          brandOrigin: 'Superflex',
          size: '12 inch',
          model: 'FD-12',
          unit: 'Meter',
          sourceBoqGroupId: 'boq-group-duct',
          sourceBoqRowId: 'boq-row-duct',
          sourceScopeId: 'scope-common',
          sourceScopeName: 'Common / All Buildings',
          sourceGroupName: 'Ductwork & Accessories',
        ),
      ];

      await tester.tap(find.text('Add Custom Item'));
      await tester.pumpAndSettle();
      final description = find.descendant(
        of: find.byKey(const ValueKey('mr-material-description-autocomplete')),
        matching: find.byType(TextFormField),
      );
      expect(description, findsOneWidget);
      await tester.enterText(description, 'flex');
      await tester.pumpAndSettle();

      expect(find.text('Flexible duct'), findsOneWidget);
      final panelSize = tester.getSize(
        find.byKey(const ValueKey('mr-suggestion-panel')),
      );
      expect(panelSize.width, greaterThanOrEqualTo(540));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/r35/mr_suggestion_overlay_desktop.png'),
      );
      expect(
        find.byKey(const ValueKey('mr-suggestion-group-scope_boq')),
        findsOneWidget,
      );
      expect(find.text('In BOQ'), findsOneWidget);
      expect(repository.lastSearchProjectId, _projectId);
      expect(repository.lastSearchScopeId, 'scope-common');
      await tester.tap(find.text('Flexible duct'));
      await tester.pumpAndSettle();

      expect(find.text('12 inch'), findsWidgets);
      expect(find.text('FD-12'), findsWidgets);
      expect(find.text('Superflex'), findsWidgets);
      expect(find.text('Meter'), findsWidgets);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(YorksV1MaterialRequestDraftScreen)),
      );
      final selectedLine = container
          .read(
            yorksV1MaterialRequestDraftControllerProvider(
              const YorksV1MaterialRequestDraftKey(
                ownerAuthUserId: 'mobile-mr-user',
                draftId: _draftId,
              ),
            ),
          )
          .draft
          .lines
          .single;
      expect(selectedLine.description, 'Flexible duct');
      expect(selectedLine.size, '12 inch');
      expect(selectedLine.model, 'FD-12');
      expect(selectedLine.brandOrigin, 'Superflex');
      expect(selectedLine.unit, 'Meter');
      expect(selectedLine.quantity, isEmpty);
      expect(tester.takeException(), isNull);
      expect(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/r35/mr_draft_inventory_row_desktop.png'),
      );
    },
  );

  testWidgets(
    'request discussion suggests authorized users from inline @ text',
    (tester) async {
      await _setViewport(tester, const Size(1366, 768));
      final repository = _MaterialRequestRepositoryFixture()
        ..mentionCandidates = const [
          YorksV1MaterialRequestMention(
            authUserId: 'ali-user-id',
            displayName: 'Ali Raza',
            exactRole: 'project_engineer',
          ),
        ];
      await tester.pumpWidget(
        _scope(
          overrides: [
            yorksV1CurrentRoleProvider.overrideWithValue(
              YorksV1Role.projectEngineer,
            ),
            yorksV1MaterialRequestRepositoryProvider.overrideWithValue(
              repository,
            ),
            yorksV1MaterialRequestDetailProvider(
              _submittedRequest.id,
            ).overrideWith((ref) async => _submittedRequest),
            yorksV1MaterialRequestDocumentProvider(
              _submittedRequest.id,
            ).overrideWith(
              (ref) async => YorksV1MaterialRequestDocumentModel.fromRequest(
                _submittedRequest,
              ),
            ),
          ],
          child: const YorksV1MaterialRequestDetailScreen(
            requestId: _submittedRequestId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final composer = find.widgetWithText(
        TextField,
        YorksV1MaterialRequestStrings.commentComposerHint.primary,
      );
      await tester.ensureVisible(composer);
      await tester.pumpAndSettle();

      expect(find.text('Request Discussion'), findsOneWidget);
      expect(find.text('Add Comment'), findsOneWidget);
      expect(find.text('No comments yet'), findsOneWidget);
      expect(
        find.text('Start the discussion by adding a comment.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('material-request-attachment-action')),
            )
            .onPressed,
        isNull,
      );
      await expectLater(
        find.byKey(const ValueKey('material-request-discussion-card')),
        matchesGoldenFile('goldens/r35/mr_discussion_empty_desktop.png'),
      );

      await tester.tap(
        find.byKey(const ValueKey('material-request-add-comment')),
      );
      await tester.pump();
      expect(tester.widget<TextField>(composer).focusNode!.hasFocus, isTrue);
      await tester.tap(
        find.byKey(const ValueKey('material-request-mention-action')),
      );
      await tester.pump();
      expect(tester.widget<TextField>(composer).controller!.text, '@');
      await tester.enterText(composer, '@ali');
      await tester.pumpAndSettle();

      expect(find.text('@aliraza'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('material-request-discussion-card')),
        matchesGoldenFile('goldens/r35/mr_discussion_mentions_desktop.png'),
      );
      await tester.tap(find.text('@aliraza'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(composer).controller!.text, '@aliraza ');

      await tester.enterText(composer, '@aliraza please review');
      await tester.tap(find.byTooltip('Post comment'));
      await tester.pumpAndSettle();

      expect(repository.addCommentInputs, hasLength(1));
      expect(repository.addCommentInputs.single.mentionedAuthUserIds, const [
        'ali-user-id',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('request discussion matches the compact mobile reference', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 800));
    final repository = _MaterialRequestRepositoryFixture();
    await tester.pumpWidget(
      _scope(
        overrides: [
          yorksV1CurrentRoleProvider.overrideWithValue(
            YorksV1Role.projectEngineer,
          ),
          yorksV1MaterialRequestRepositoryProvider.overrideWithValue(
            repository,
          ),
          yorksV1MaterialRequestDetailProvider(
            _submittedRequest.id,
          ).overrideWith((ref) async => _submittedRequest),
          yorksV1MaterialRequestDocumentProvider(
            _submittedRequest.id,
          ).overrideWith(
            (ref) async => YorksV1MaterialRequestDocumentModel.fromRequest(
              _submittedRequest,
            ),
          ),
        ],
        child: const YorksV1MaterialRequestDetailScreen(
          requestId: _submittedRequestId,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _showFullMaterialRequestDetails(tester);

    final composer = find.byKey(
      const ValueKey('material-request-comment-composer'),
    );
    await tester.scrollUntilVisible(
      composer,
      420,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('mobile-mr-lifecycle')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Request Discussion'), findsOneWidget);
    expect(find.text('Add Comment'), findsOneWidget);
    expect(find.text('No comments yet'), findsOneWidget);
    expect(composer, findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('material-request-discussion-card')),
      matchesGoldenFile('goldens/r35/mr_discussion_empty_mobile_360.png'),
    );
  });

  testWidgets('mobile request approval stays reachable in the safe-area bar', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 800));
    final repository = _MaterialRequestRepositoryFixture();
    final request = _requestVariant(
      id: 'mobile-request-awaiting-approval',
      state: YorksV1MaterialRequestState.awaitingRequestApproval,
      canDecideRequest: true,
      canEditBeforeApproval: true,
    );
    await tester.pumpWidget(
      _scope(
        overrides: [
          yorksV1CurrentRoleProvider.overrideWithValue(
            YorksV1Role.projectEngineer,
          ),
          yorksV1MaterialRequestRepositoryProvider.overrideWithValue(
            repository,
          ),
          yorksV1MaterialRequestDetailProvider(
            request.id,
          ).overrideWith((ref) async => request),
          yorksV1MaterialRequestDocumentProvider(request.id).overrideWith(
            (ref) async =>
                YorksV1MaterialRequestDocumentModel.fromRequest(request),
          ),
        ],
        child: YorksV1MaterialRequestDetailScreen(requestId: request.id),
      ),
    );
    await tester.pumpAndSettle();

    final sticky = find.byKey(
      const ValueKey('mobile-mr-request-approval-actions'),
    );
    expect(sticky, findsOneWidget);
    expect(find.text('Approve for Procurement'), findsOneWidget);
    expect(find.text('Return for changes'), findsOneWidget);
    final rect = tester.getRect(sticky);
    expect(rect.bottom, lessThanOrEqualTo(800));
    expect(rect.height, greaterThanOrEqualTo(AppSpacing.minTapTarget));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/r35/mr_request_approval_sticky_mobile_360.png',
      ),
    );
  });

  testWidgets('request discussion caps its history and scrolls independently', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    final repository = _MaterialRequestRepositoryFixture();
    final request = _requestVariant(
      id: 'discussion-scroll-request',
      comments: _discussionComments('discussion-scroll-request'),
    );
    await tester.pumpWidget(
      _scope(
        overrides: [
          yorksV1CurrentRoleProvider.overrideWithValue(
            YorksV1Role.projectEngineer,
          ),
          yorksV1MaterialRequestRepositoryProvider.overrideWithValue(
            repository,
          ),
          yorksV1MaterialRequestDetailProvider(
            request.id,
          ).overrideWith((ref) async => request),
          yorksV1MaterialRequestDocumentProvider(request.id).overrideWith(
            (ref) async =>
                YorksV1MaterialRequestDocumentModel.fromRequest(request),
          ),
        ],
        child: YorksV1MaterialRequestDetailScreen(requestId: request.id),
      ),
    );
    await tester.pumpAndSettle();

    final region = find.byKey(
      const ValueKey('material-request-discussion-scroll'),
    );
    final scrollable = find.descendant(
      of: region,
      matching: find.byType(Scrollable),
    );
    expect(region, findsOneWidget);
    expect(tester.getSize(region).height, lessThanOrEqualTo(420));
    expect(scrollable, findsOneWidget);
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, greaterThan(0));

    await tester.ensureVisible(region);
    await tester.pumpAndSettle();
    await tester.drag(scrollable, const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    expect(
      find.byKey(const ValueKey('material-request-comment-composer')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('material-request-discussion-card')),
      matchesGoldenFile('goldens/r35/mr_discussion_scroll_desktop.png'),
    );
  });

  testWidgets('mobile request discussion stays bounded at 360px', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 800));
    final repository = _MaterialRequestRepositoryFixture();
    final request = _requestVariant(
      id: 'discussion-scroll-mobile-request',
      comments: _discussionComments('discussion-scroll-mobile-request'),
    );
    await tester.pumpWidget(
      _scope(
        overrides: [
          yorksV1CurrentRoleProvider.overrideWithValue(
            YorksV1Role.projectEngineer,
          ),
          yorksV1MaterialRequestRepositoryProvider.overrideWithValue(
            repository,
          ),
          yorksV1MaterialRequestDetailProvider(
            request.id,
          ).overrideWith((ref) async => request),
          yorksV1MaterialRequestDocumentProvider(request.id).overrideWith(
            (ref) async =>
                YorksV1MaterialRequestDocumentModel.fromRequest(request),
          ),
        ],
        child: YorksV1MaterialRequestDetailScreen(requestId: request.id),
      ),
    );
    await tester.pumpAndSettle();
    await _showFullMaterialRequestDetails(tester);

    final region = find.byKey(
      const ValueKey('material-request-discussion-scroll'),
    );
    await tester.scrollUntilVisible(
      region,
      420,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('mobile-mr-lifecycle')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: region,
      matching: find.byType(Scrollable),
    );
    expect(tester.getSize(region).height, lessThanOrEqualTo(300));
    expect(scrollable, findsOneWidget);
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, greaterThan(0));
    await tester.drag(scrollable, const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    expect(
      find.byKey(const ValueKey('material-request-comment-composer')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('material-request-discussion-card')),
      matchesGoldenFile('goldens/r35/mr_discussion_scroll_mobile_360.png'),
    );
  });

  testWidgets('closed request renders all seven lifecycle stages complete', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    final request = _requestVariant(
      id: 'closed-workflow-request',
      state: YorksV1MaterialRequestState.closed,
    );
    await tester.pumpWidget(
      _scope(
        overrides: [
          yorksV1CurrentRoleProvider.overrideWithValue(
            YorksV1Role.projectEngineer,
          ),
          yorksV1MaterialRequestDetailProvider(
            request.id,
          ).overrideWith((ref) async => request),
          yorksV1MaterialRequestDocumentProvider(request.id).overrideWith(
            (ref) async =>
                YorksV1MaterialRequestDocumentModel.fromRequest(request),
          ),
        ],
        child: YorksV1MaterialRequestDetailScreen(requestId: request.id),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final workflow = find.byKey(
      const ValueKey('material-request-workflow-strip'),
    );
    expect(workflow, findsOneWidget);
    expect(
      find.descendant(of: workflow, matching: find.byIcon(Icons.check_rounded)),
      findsNWidgets(7),
    );
    expect(find.text('Stage 7 of 7'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      workflow,
      matchesGoldenFile('goldens/r35/mr_closed_workflow_desktop.png'),
    );
  });

  testWidgets('closed request completes mobile lifecycle at 360px', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 800));
    final request = _requestVariant(
      id: 'closed-workflow-mobile-request',
      state: YorksV1MaterialRequestState.closed,
    );
    await tester.pumpWidget(
      _scope(
        overrides: [
          yorksV1CurrentRoleProvider.overrideWithValue(
            YorksV1Role.projectEngineer,
          ),
          yorksV1MaterialRequestDetailProvider(
            request.id,
          ).overrideWith((ref) async => request),
          yorksV1MaterialRequestDocumentProvider(request.id).overrideWith(
            (ref) async =>
                YorksV1MaterialRequestDocumentModel.fromRequest(request),
          ),
        ],
        child: YorksV1MaterialRequestDetailScreen(requestId: request.id),
      ),
    );
    await tester.pumpAndSettle();
    await _showFullMaterialRequestDetails(tester);

    final workflow = find.byKey(
      const ValueKey('material-request-mobile-workflow'),
    );
    await tester.scrollUntilVisible(
      workflow,
      420,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('mobile-mr-lifecycle')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    expect(workflow, findsOneWidget);
    expect(
      find.descendant(of: workflow, matching: find.byIcon(Icons.check_rounded)),
      findsNWidgets(7),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      workflow,
      matchesGoldenFile('goldens/r35/mr_closed_workflow_mobile_360.png'),
    );
  });

  testWidgets('desktop MR BOQ picker selects scoped rows without duplicates', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    await _pumpDraft(tester, boqRepository: _DesktopBoqRepositoryFixture());

    await tester.tap(find.text('Add from BOQ'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('desktop-mr-boq-picker')), findsOneWidget);
    expect(
      find.text('Add Items from Common / All Buildings BOQ'),
      findsOneWidget,
    );
    expect(find.textContaining('Air outlets'), findsOneWidget);
    final addButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('desktop-mr-add-selected-boq-items')),
    );
    expect(addButton.onPressed, isNull);

    await tester.tap(
      find.byKey(const ValueKey('desktop-mr-boq-row-mobile-mr-boq-row')),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/r35/mr_boq_picker_populated_desktop.png'),
    );

    await tester.tap(
      find.byKey(const ValueKey('desktop-mr-add-selected-boq-items')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Flexible duct'), findsOneWidget);

    await tester.tap(find.text('Add from BOQ'));
    await tester.pumpAndSettle();
    expect(find.text('Already added'), findsOneWidget);
    final rowCheckbox = tester.widget<Checkbox>(
      find.byKey(const ValueKey('desktop-mr-boq-row-mobile-mr-boq-row')),
    );
    expect(rowCheckbox.onChanged, isNull);
  });

  testWidgets('BOQ folder route seeds project scope before copying rows', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    await _pumpDraft(
      tester,
      boqRepository: _DesktopBoqRepositoryFixture(),
      boqGroupId: 'mobile-mr-boq-group',
    );

    expect(find.text('Flexible duct'), findsOneWidget);
    expect(find.text('Common / All Buildings'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop MR Back offers keep, discard, or save before leaving', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    await _pumpDraft(tester);
    await tester.enterText(
      find.byKey(const ValueKey('mr-title')),
      'Keep this request',
    );
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Save this material request?'), findsOneWidget);
    expect(find.byKey(const ValueKey('mr-draft-keep-editing')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mr-draft-discard-and-leave')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mr-draft-save-and-leave')),
      findsOneWidget,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/r35/mr_draft_exit_guard_desktop.png'),
    );

    await tester.tap(find.byKey(const ValueKey('mr-draft-keep-editing')));
    await tester.pumpAndSettle();
    expect(find.text('Save this material request?'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mr-draft-save-and-leave')));
    await tester.pumpAndSettle();
    expect(find.text('Save this material request?'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Save this material request?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop MR BOQ picker has a truthful empty state', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    await _pumpDraft(tester, boqRepository: _EmptyBoqRepositoryFixture());

    await tester.tap(find.text('Add from BOQ'));
    await tester.pumpAndSettle();

    expect(
      find.text('No materials in Common / All Buildings BOQ'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Add or import materials into this scope'),
      findsOneWidget,
    );
    final addButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('desktop-mr-add-selected-boq-items')),
    );
    expect(addButton.onPressed, isNull);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/r35/mr_boq_picker_empty_desktop.png'),
    );
  });

  for (final size in [const Size(390, 844), const Size(360, 800)]) {
    final suffix = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('mobile Batch 3 MR register $suffix', (tester) async {
      await _setViewport(tester, size);
      await tester.pumpWidget(
        _scope(
          overrides: [
            yorksV1CurrentRoleProvider.overrideWithValue(
              YorksV1Role.projectEngineer,
            ),
            yorksV1MaterialRequestListProvider(
              null,
            ).overrideWith((ref) async => [_submittedRequest, _draftRequest]),
          ],
          child: const YorksV1MaterialRequestsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('mobile-material-request-register')),
        findsOneWidget,
      );
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.text('My Work'), findsOneWidget);
      expect(find.text('All Requests'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mobile-mr-new-request')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('mobile-mr-search')), findsOneWidget);
      expect(find.byKey(const ValueKey('mobile-mr-filters')), findsOneWidget);
      expect(find.text('YRA-322-MR101'), findsOneWidget);
      expect(find.text('Draft'), findsWidgets);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_batch3/mr_register_$suffix.png'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile MR filter sheet stays complete at $suffix', (
      tester,
    ) async {
      await _setViewport(tester, size);
      await tester.pumpWidget(
        _scope(
          overrides: [
            yorksV1CurrentRoleProvider.overrideWithValue(
              YorksV1Role.projectEngineer,
            ),
            yorksV1MaterialRequestListProvider(
              null,
            ).overrideWith((ref) async => [_submittedRequest, _draftRequest]),
          ],
          child: const YorksV1MaterialRequestsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('mobile-mr-filters')));
      await tester.pumpAndSettle();

      expect(find.text('Requests to show'), findsOneWidget);
      expect(find.text('Exceptions'), findsOneWidget);
      expect(find.text('My Material Requests'), findsOneWidget);
      expect(find.text('Coordinated Requests'), findsOneWidget);
      expect(find.text('Workflow status'), findsOneWidget);
      expect(find.text('All statuses'), findsOneWidget);
      expect(find.text('Apply filters'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile Batch 3 MR information $suffix', (tester) async {
      await _setViewport(tester, size);
      await _pumpDraft(tester);

      expect(
        find.byKey(const ValueKey('mobile-mr-information')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('mobile-mr-project')), findsOneWidget);
      expect(find.byKey(const ValueKey('mobile-mr-scope')), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_batch3/mr_information_$suffix.png'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile MR Back protects draft progress $suffix', (
      tester,
    ) async {
      await _setViewport(tester, size);
      await _pumpDraft(tester);
      await tester.enterText(
        find.byKey(const ValueKey('mobile-mr-title')),
        'Protected request',
      );
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Save this material request?'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mr-draft-save-and-leave')),
        findsOneWidget,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/mobile_batch3/mr_draft_exit_guard_$suffix.png',
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile material basket stays compact at $suffix', (
      tester,
    ) async {
      await _setViewport(tester, size);
      await _pumpDraft(tester);
      await _continueToMaterials(tester);

      expect(find.text('Material basket'), findsOneWidget);
      expect(find.text('No materials added yet.'), findsOneWidget);
      final fromBoq = find.byKey(const ValueKey('mobile-mr-add-from-boq'));
      final custom = find.byKey(const ValueKey('mobile-mr-add-custom'));
      expect(fromBoq, findsOneWidget);
      expect(custom, findsOneWidget);
      expect(
        tester.getSize(fromBoq).height,
        greaterThanOrEqualTo(AppSpacing.minTapTarget),
      );
      expect(
        tester.getSize(custom).height,
        greaterThanOrEqualTo(AppSpacing.minTapTarget),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/mobile_batch3/mr_material_basket_empty_$suffix.png',
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile Batch 3 MR BOQ folders $suffix', (tester) async {
      await _setViewport(tester, size);
      await _pumpDraft(tester, boqRepository: _BoqRepositoryFixture());
      await _continueToMaterials(tester);

      await tester.tap(find.text('Add from BOQ'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('mobile-mr-boq-folders')),
        findsOneWidget,
      );
      expect(find.text('Air outlets'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_batch3/mr_boq_folders_$suffix.png'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile Batch 3 MR custom material $suffix', (tester) async {
      await _setViewport(tester, size);
      await _pumpDraft(tester);
      await _continueToMaterials(tester);

      await tester.tap(find.text('Add Custom Item'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('mobile-mr-custom-material')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mobile-custom-quantity')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mobile-custom-technical-details-toggle')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('mobile-custom-brand')), findsOneWidget);
      expect(find.byKey(const ValueKey('mobile-custom-size')), findsOneWidget);
      expect(find.byKey(const ValueKey('mobile-custom-model')), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/mobile_batch3/mr_custom_material_$suffix.png',
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile Batch 3 MR review $suffix', (tester) async {
      await _setViewport(tester, size);
      await _pumpDraft(tester);
      await _addCustomMaterial(tester);
      await _openReview(tester);

      expect(find.byKey(const ValueKey('mobile-mr-review')), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_batch3/mr_review_$suffix.png'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile Batch 3 MR submitted $suffix', (tester) async {
      await _setViewport(tester, size);
      final repository = await _pumpDraft(tester);
      await _addCustomMaterial(tester);
      await _openReview(tester);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('mobile-mr-primary-action')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(
        find
            .byKey(const ValueKey('mobile-mr-primary-action'))
            .hitTestable()
            .first,
      );
      await tester.pumpAndSettle();

      expect(repository.saveAndSubmitCount, 1);
      expect(
        find.text(YorksV1MaterialRequestStrings.serverConfirmed.primary),
        findsOneWidget,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_batch3/mr_submitted_$suffix.png'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile Batch 3 MR lifecycle $suffix', (tester) async {
      await _setViewport(tester, size);
      await _pumpLifecycle(tester);

      expect(find.byKey(const ValueKey('mobile-mr-lifecycle')), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_batch3/mr_lifecycle_$suffix.png'),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('mobile request switches from key facts to the full ledger', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 800));
    final controlledDocument = YorksV1MaterialRequestDocumentModel(
      request: _submittedRequest,
      showLineStatus: true,
      lineLifecycles: const {
        'submitted-line': YorksV1MaterialRequestLineLifecycle(
          requestLineId: 'submitted-line',
          requestedQuantity: '10',
          arrangedQuantity: '8',
          cannotProvideQuantity: '2',
          approvedQuantity: '8',
          reservedQuantity: '2',
          dispatchedQuantity: '6',
          inTransitQuantity: '1',
          goodQuantity: '4',
          missingQuantity: '1',
          damagedQuantity: '1',
          returnedQuantity: '1',
          stillNeededQuantity: '5',
          remainingApprovedQuantity: '3',
          replacementEligibleQuantity: '2',
          ordinaryOutstandingQuantity: '1',
          status: 'Replacement required',
        ),
      },
    );
    await tester.pumpWidget(
      _scope(
        overrides: [
          yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.procurement),
          yorksV1MaterialRequestDetailProvider(
            _submittedRequest.id,
          ).overrideWith((ref) async => _submittedRequest),
          yorksV1MaterialRequestDocumentProvider(
            _submittedRequest.id,
          ).overrideWith((ref) async => controlledDocument),
        ],
        child: const YorksV1MaterialRequestDetailScreen(
          requestId: _submittedRequestId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mobile-mr-lifecycle')), findsOneWidget);
    expect(find.text('Simple'), findsOneWidget);
    expect(find.text('Full details'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('mobile-mr-detail-mode')))
          .height,
      greaterThanOrEqualTo(AppSpacing.minTapTarget),
    );
    expect(find.text('Reserved'), findsNothing);
    expect(find.text('Still needed'), findsOneWidget);
    expect(find.text('Missing'), findsOneWidget);
    expect(find.text('Damaged'), findsOneWidget);

    await _showFullMaterialRequestDetails(tester);

    expect(find.text('Reserved'), findsOneWidget);
    expect(find.text('Returned'), findsOneWidget);
    expect(find.text('Still needed'), findsOneWidget);
    expect(find.text('2 Nos'), findsWidgets);
    expect(find.text('1 Nos'), findsWidgets);
    expect(find.text('5 Nos'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/mobile_batch3/mr_lifecycle_full_360x800.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mobile MR uses the existing draft controller through custom material',
    (tester) async {
      await _setViewport(tester, const Size(390, 844));
      await _pumpDraft(tester);
      await _addCustomMaterial(tester);
      expect(find.text('Flexible duct'), findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );

  for (final testCase in const [
    (name: 'mobile', size: Size(390, 844), minimumPanelWidth: 350.0),
    (name: 'tablet', size: Size(700, 1000), minimumPanelWidth: 470.0),
  ]) {
    testWidgets(
      '${testCase.name} custom material keeps rich suggestions anchored and readable',
      (tester) async {
        await _setViewport(tester, testCase.size);
        final repository = await _pumpDraft(tester);
        repository.inventorySuggestions = const [
          YorksV1MaterialRequestInventorySuggestion(
            id: 'boq-row-mobile-duct',
            source: YorksV1MaterialRequestSuggestionSource.selectedScopeBoq,
            description: 'Flexible duct',
            brandOrigin: 'Superflex',
            size: '12 inch',
            model: 'FD-12',
            unit: 'Meter',
            sourceBoqGroupId: 'boq-group-duct',
            sourceBoqRowId: 'boq-row-mobile-duct',
            sourceScopeId: 'scope-common',
            sourceScopeName: 'Common / All Buildings',
          ),
        ];
        if (find
            .byKey(const ValueKey('mobile-mr-primary-action'))
            .evaluate()
            .isNotEmpty) {
          await _continueToMaterials(tester);
        }
        await tester.ensureVisible(find.text('Add Custom Item').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add Custom Item').first);
        await tester.pumpAndSettle();

        final description = find.descendant(
          of: find.byKey(
            const ValueKey('mr-material-description-autocomplete'),
          ),
          matching: find.byType(TextFormField),
        );
        await tester.enterText(description, 'flex');
        await tester.pumpAndSettle();

        expect(find.text('Flexible duct'), findsOneWidget);
        final panelSize = tester.getSize(
          find.byKey(const ValueKey('mr-suggestion-panel')),
        );
        expect(
          panelSize.width,
          greaterThanOrEqualTo(testCase.minimumPanelWidth),
        );
        expect(panelSize.width, lessThanOrEqualTo(testCase.size.width - 32));
        expect(find.textContaining('12 inch'), findsOneWidget);
        expect(find.textContaining('FD-12'), findsOneWidget);
        expect(find.textContaining('Superflex'), findsOneWidget);
        expect(find.textContaining('Common / All Buildings'), findsWidgets);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/mobile_batch3/mr_suggestion_overlay_${testCase.name}.png',
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('mobile custom material explains missing fields on action', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    await _pumpDraft(tester);
    await _continueToMaterials(tester);

    await tester.tap(find.text('Add Custom Item'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Custom Item').hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Item description is required'), findsWidgets);
    expect(find.text('Select a valid unit'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile custom material keeps all detail fields open', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 800));
    await _pumpDraft(tester);
    await _continueToMaterials(tester);
    await tester.tap(find.byKey(const ValueKey('mobile-mr-add-custom')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('mobile-custom-technical-details-toggle')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('mobile-custom-brand')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-custom-size')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-custom-model')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small mobile duplicates a selected row and reviews its details', (
    tester,
  ) async {
    await _setViewport(tester, const Size(320, 568));
    await _pumpDraft(tester);
    await _addCustomMaterial(tester);

    await tester.scrollUntilVisible(
      find.byTooltip('Add Similar Row'),
      120,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('mobile-mr-materials')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.byTooltip('Add Similar Row'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add Similar Row').hitTestable());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('mobile-mr-custom-material')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('mobile-custom-quantity')),
      '3',
    );
    await tester.tap(find.text('Save Changes').hitTestable());
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('3 Nos'),
      120,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('mobile-mr-materials')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('3 Nos'), findsOneWidget);
    expect(find.byTooltip('Add Similar Row'), findsAtLeastNWidgets(1));

    // Remove the completed duplicate, then verify that the review stage shows
    // the selected material itself and its requested quantity on a short phone.
    await tester.ensureVisible(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close_rounded).hitTestable().last);
    await tester.pumpAndSettle();
    await _openReview(tester);
    await tester.scrollUntilVisible(
      find.text('Flexible duct'),
      120,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('mobile-mr-review')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(find.text('2 Nos'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mobile-mr-review')), findsOneWidget);
    expect(find.text('Flexible duct'), findsOneWidget);
    expect(find.text('2 Nos'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/r35/mr_review_small_phone_320x568.png'),
    );
  });

  testWidgets('mobile MR adds only a row from the selected real BOQ scope', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    await _pumpDraft(tester, boqRepository: _BoqRepositoryFixture());
    await _continueToMaterials(tester);

    await tester.tap(find.text('Add from BOQ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Air outlets'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mobile-mr-boq-rows')), findsOneWidget);
    expect(find.text('Flexible duct'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .byKey(const ValueKey('mobile-mr-primary-action'))
          .hitTestable()
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mobile-mr-materials')), findsOneWidget);
    expect(find.text('Flexible duct'), findsOneWidget);
    // The root-overlay success notice deliberately remains visible across a
    // route/state change. Let its bounded lifetime finish before the widget
    // test tears down the navigator.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mobile MR lifecycle exposes only the real resolved primary action',
    (tester) async {
      await _setViewport(tester, const Size(390, 844));
      await _pumpLifecycle(tester);

      expect(find.byKey(const ValueKey('mobile-mr-lifecycle')), findsOneWidget);
      expect(find.text('Arrange Items'), findsNothing);
      expect(find.text('Current owner'), findsOneWidget);
      expect(find.text('Simple'), findsOneWidget);
      expect(find.text('Request Discussion'), findsNothing);
      expect(find.textContaining('Unit Cost'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile composer follows the active Arabic RTL language', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 800));
    await _pumpDraft(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(YorksV1MaterialRequestDraftScreen)),
    );
    await container
        .read(languageProvider.notifier)
        .setLanguage(AppLanguage.arabic);
    await tester.pumpAndSettle();

    expect(
      find.text(
        YorksV1MaterialRequestStrings.whereNeeded.active(AppLanguage.arabic),
      ),
      findsOneWidget,
    );
    expect(
      Directionality.of(
        tester.element(find.byKey(const ValueKey('mobile-mr-information'))),
      ),
      TextDirection.rtl,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/mobile_batch3/mr_information_arabic_rtl_360x800.png',
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('mobile-mr-primary-action')).hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        YorksV1MaterialRequestStrings.materialBasket.active(AppLanguage.arabic),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('mobile-mr-add-custom')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        YorksV1MaterialRequestStrings.brandOrigin.active(AppLanguage.arabic),
      ),
      findsOneWidget,
    );
    expect(
      find.text(YorksV1MaterialRequestStrings.size.active(AppLanguage.arabic)),
      findsOneWidget,
    );
    expect(
      find.text(
        YorksV1MaterialRequestStrings.planningModelTag.active(
          AppLanguage.arabic,
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile MR routes use one feature header with shell navigation', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    final router = GoRouter(
      initialLocation: RoutePaths.yorksV1MaterialRequests,
      routes: [
        GoRoute(
          path: RoutePaths.yorksV1MaterialRequests,
          builder: (_, _) => const YorksV1WorkspaceShell(
            child: YorksV1MaterialRequestsScreen(),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      _scope(
        overrides: [
          yorksV1CurrentRoleProvider.overrideWithValue(
            YorksV1Role.projectEngineer,
          ),
          yorksV1MaterialRequestListProvider(
            null,
          ).overrideWith((ref) async => [_submittedRequest]),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: router,
        ),
        materialApp: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(YorksV1WorkspaceShell), findsOneWidget);
    expect(find.text('Material Requests'), findsNWidgets(2));
    expect(find.text('Requests'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile MR filters stay consolidated and touch safe', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 800));
    await tester.pumpWidget(
      _scope(
        overrides: [
          yorksV1CurrentRoleProvider.overrideWithValue(
            YorksV1Role.projectEngineer,
          ),
          yorksV1MaterialRequestListProvider(
            null,
          ).overrideWith((ref) async => [_submittedRequest, _draftRequest]),
        ],
        child: const YorksV1MaterialRequestsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final filters = find.byKey(const ValueKey('mobile-mr-filters'));
    expect(filters, findsOneWidget);
    expect(tester.getSize(filters).height, greaterThanOrEqualTo(48));
    expect(
      find.byKey(const ValueKey('mobile-mr-primary-views')),
      findsOneWidget,
    );
    expect(find.text('My Work'), findsOneWidget);
    expect(find.text('All Requests'), findsOneWidget);

    await tester.tap(filters);
    await tester.pumpAndSettle();
    expect(find.text('Requests to show'), findsOneWidget);
    expect(find.text('Workflow status'), findsOneWidget);
    expect(find.text('Apply filters'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile register shows due, age and exception facts', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 800));
    final request = _summaryProjection(
      id: 'mobile-action-facts',
      state: YorksV1MaterialRequestState.approvedForArrangement,
      itemCount: 7,
      scheduledDate: DateTime.utc(2026, 8, 19),
      currentActionAgeHours: 27.5,
      requiredOnSiteOverdue: true,
      actorCanAct: true,
      exceptionCodes: const [
        YorksV1MaterialRequestExceptionCode.partialArrangement,
      ],
    );
    await tester.pumpWidget(
      _scope(
        overrides: [
          yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.procurement),
          yorksV1MaterialRequestListProvider(
            null,
          ).overrideWith((ref) async => [request]),
        ],
        child: const YorksV1MaterialRequestsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Required on site'), findsOneWidget);
    expect(find.textContaining('Action age'), findsOneWidget);
    expect(find.text('Partial arrangement'), findsOneWidget);
    expect(find.text('7 items'), findsOneWidget);
    expect(find.text('Arrange Items'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mobile-mr-card-action-mobile-action-facts')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mobile All Requests retains every approval and arrangement state',
    (tester) async {
      await _setViewport(tester, const Size(360, 800));
      for (final state in yorksV1MaterialRequestSubmittedRegisterStates) {
        final request = _summaryProjection(
          id: 'submitted-${state.wireValue}',
          state: state,
          itemCount: 27,
        );
        await tester.pumpWidget(
          _scope(
            overrides: [
              yorksV1CurrentRoleProvider.overrideWithValue(
                YorksV1Role.projectEngineer,
              ),
              yorksV1MaterialRequestListProvider(
                null,
              ).overrideWith((ref) async => [request]),
            ],
            child: const YorksV1MaterialRequestsScreen(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('All Requests'));
        await tester.pumpAndSettle();

        expect(
          find.text('MR-${state.wireValue}'),
          findsOneWidget,
          reason: 'state ${state.wireValue}',
        );
        expect(find.text('27 items'), findsOneWidget);
        expect(
          find.textContaining('Current owner: Procurement'),
          findsOneWidget,
        );
        expect(find.textContaining('Next action:'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancelled all-unavailable replacement action stacks cleanly at 360px',
    (tester) async {
      await _setViewport(tester, const Size(360, 800));
      final request = _requestVariant(
        id: 'cancelled-unavailable-request',
        state: YorksV1MaterialRequestState.cancelled,
      );
      await tester.pumpWidget(
        _scope(
          overrides: [
            yorksV1CurrentRoleProvider.overrideWithValue(
              YorksV1Role.projectManager,
            ),
            yorksV1MaterialRequestDetailProvider(
              request.id,
            ).overrideWith((ref) async => request),
            yorksV1MaterialRequestPhase3PolicyProvider(request.id).overrideWith(
              (ref) async => YorksV1MaterialRequestPhase3Policy(
                requestId: request.id,
                allowAuthorizedCreatorSelfApproval: true,
                requireExternalSourceReadiness: false,
                canCreateReplacement: true,
                replacementExists: false,
              ),
            ),
            yorksV1MaterialRequestDocumentProvider(request.id).overrideWith(
              (ref) async =>
                  YorksV1MaterialRequestDocumentModel.fromRequest(request),
            ),
          ],
          child: YorksV1MaterialRequestDetailScreen(requestId: request.id),
        ),
      );
      await tester.pumpAndSettle();

      final card = find.byKey(
        const ValueKey('material-request-replacement-card'),
      );
      final action = find.byKey(
        const ValueKey('create-replacement-material-request'),
      );
      expect(card, findsOneWidget);
      expect(action, findsOneWidget);
      expect(tester.getSize(action).width, greaterThan(250));
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(1366, 768), const Size(360, 800)]) {
    final suffix = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('MR register exposes owner-local draft recovery $suffix', (
      tester,
    ) async {
      await _setViewport(tester, size);
      const ownerAuthUserId = 'recoverable-draft-owner';
      final repository = _MaterialRequestRepositoryFixture();
      final recoveryContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(_preferences),
          yorksV1MaterialRequestRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
      );
      addTearDown(recoveryContainer.dispose);
      final draftController = recoveryContainer.read(
        yorksV1MaterialRequestDraftControllerProvider(
          const YorksV1MaterialRequestDraftKey(
            ownerAuthUserId: ownerAuthUserId,
            draftId: 'recoverable-local-draft',
          ),
        ).notifier,
      );
      await draftController.setTitle('Plant room materials');
      await draftController.setProject(_projectId);

      await tester.pumpWidget(
        _scope(
          overrides: [
            yorksV1AuthUserIdProvider.overrideWithValue(ownerAuthUserId),
            yorksV1CurrentRoleProvider.overrideWithValue(
              YorksV1Role.projectEngineer,
            ),
            yorksV1MaterialRequestRepositoryProvider.overrideWithValue(
              repository,
            ),
            yorksV1MaterialRequestListProvider(
              null,
            ).overrideWith((ref) async => [_submittedRequest]),
          ],
          child: const YorksV1MaterialRequestsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 saved local draft'), findsOneWidget);
      expect(find.text('Plant room materials'), findsOneWidget);
      expect(find.text('Resume saved draft'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/r35/mr_local_recovery_$suffix.png'),
      );
      expect(tester.takeException(), isNull);
    });
  }
}

Widget _scope({
  required List<Override> overrides,
  required Widget child,
  bool materialApp = true,
}) => ProviderScope(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(_preferences),
    yorksV1CurrentPermissionSnapshotProvider.overrideWith(
      (ref) => YorksV1TestPermissionController(
        yorksV1TrustedFeaturePermissionState(),
      ),
    ),
    ...overrides,
  ],
  child: materialApp
      ? MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: child,
        )
      : child,
);

Future<_MaterialRequestRepositoryFixture> _pumpDraft(
  WidgetTester tester, {
  YorksV1BoqRepository? boqRepository,
  String? boqGroupId,
  YorksV1RuntimeConfiguration? runtimeConfiguration,
  YorksV1MaterialRequest? serverRequest,
  String? initialProjectId = _projectId,
  List<YorksV1MaterialRequestProjectOption>? projectOptions,
}) async {
  final projects = projectOptions ?? _draftProjects.take(1).toList();
  final repository = _MaterialRequestRepositoryFixture(
    serverRequest: serverRequest,
  );
  await tester.pumpWidget(
    _scope(
      overrides: [
        yorksV1AuthUserIdProvider.overrideWithValue('mobile-mr-user'),
        yorksV1CurrentRoleProvider.overrideWithValue(
          YorksV1Role.projectEngineer,
        ),
        yorksV1MaterialRequestRepositoryProvider.overrideWithValue(repository),
        yorksV1RuntimeConfigurationProvider.overrideWith(
          (ref) async => runtimeConfiguration ?? _runtimeConfiguration(),
        ),
        yorksV1ConfigurationUnitCodesProvider.overrideWith(
          (ref) async => const ['Nos', 'Meter', 'Set'],
        ),
        if (boqRepository != null)
          yorksV1BoqRepositoryProvider.overrideWithValue(boqRepository),
        yorksV1MaterialRequestDraftProjectsProvider.overrideWith(
          (ref) async => projects,
        ),
        yorksV1MaterialRequestScopesProvider(_projectId).overrideWith(
          (ref) async => const [
            YorksV1MaterialRequestScopeOption(
              id: 'scope-common',
              projectId: _projectId,
              name: 'Common / All Buildings',
              kind: 'common',
            ),
          ],
        ),
        for (final project in projects.where((item) => item.id != _projectId))
          yorksV1MaterialRequestScopesProvider(project.id).overrideWith(
            (ref) async => [
              YorksV1MaterialRequestScopeOption(
                id: 'scope-${project.id}',
                projectId: project.id,
                name: 'Common / All Buildings',
                kind: 'common',
              ),
            ],
          ),
      ],
      child: YorksV1MaterialRequestDraftScreen(
        draftId: _draftId,
        projectId: initialProjectId,
        boqGroupId: boqGroupId,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Future<void> _continueToMaterials(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey('mobile-mr-primary-action')).hitTestable().first,
  );
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('mobile-mr-materials')), findsOneWidget);
}

Future<void> _addCustomMaterial(WidgetTester tester) async {
  await _continueToMaterials(tester);
  await tester.tap(find.text('Add Custom Item'));
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey('mobile-mr-custom-material')),
    findsOneWidget,
  );

  await tester.enterText(
    find.descendant(
      of: find.byKey(const ValueKey('mobile-custom-description')),
      matching: find.byType(TextFormField),
    ),
    'Flexible duct',
  );
  await tester.enterText(
    find.byKey(const ValueKey('mobile-custom-quantity')),
    '2',
  );
  await tester.tap(
    find
        .descendant(
          of: find.byKey(const ValueKey('mobile-custom-material-unit')),
          matching: find.byType(DropdownButton<String>),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Nos').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add Custom Item'));
  await tester.pumpAndSettle();
  // The honest success toast is intentionally visible before returning to the
  // material list. Let it finish so the fixed action bar is hit-testable.
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

Future<void> _openReview(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey('mobile-mr-primary-action')).hitTestable().first,
  );
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('mobile-mr-review')), findsOneWidget);
}

Future<void> _showFullMaterialRequestDetails(WidgetTester tester) async {
  final fullDetails = find.descendant(
    of: find.byKey(const ValueKey('mobile-mr-detail-mode')),
    matching: find.text('Full details'),
  );
  expect(fullDetails, findsOneWidget);
  await tester.tap(fullDetails);
  await tester.pumpAndSettle();
}

Future<void> _pumpLifecycle(WidgetTester tester) async {
  await tester.pumpWidget(
    _scope(
      overrides: [
        yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.procurement),
        yorksV1MaterialRequestDetailProvider(
          _submittedRequest.id,
        ).overrideWith((ref) async => _submittedRequest),
        yorksV1MaterialRequestDocumentProvider(
          _submittedRequest.id,
        ).overrideWith(
          (ref) async => YorksV1MaterialRequestDocumentModel.fromRequest(
            _submittedRequest,
          ),
        ),
      ],
      child: const YorksV1MaterialRequestDetailScreen(
        requestId: _submittedRequestId,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 26);
  tester.view.viewPadding = const FakeViewPadding(top: 26);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPadding();
    tester.view.resetViewPadding();
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

const _submittedRequestId = 'mobile-mr-submitted';

final _submittedRequest = YorksV1MaterialRequest(
  id: _submittedRequestId,
  projectId: _projectId,
  projectReference: 'YRA-322',
  projectName: 'Al Dhafra Grid Substation HVAC Works',
  scopeId: 'scope-common',
  scopeName: 'Common / All Buildings',
  state: YorksV1MaterialRequestState.approvedForArrangement,
  recordVersion: 2,
  createdAt: DateTime.utc(2026, 8, 9),
  updatedAt: DateTime.utc(2026, 8, 9),
  timing: YorksV1MaterialRequestTiming.normal,
  requestNumber: 'YRA-322-MR101',
  title: 'Level 2 FCU materials',
  requesterDisplayName: 'Omar Farooq',
  requesterProjectRole: 'Project Engineer',
  currentActionOwnerRole: 'procurement',
  currentActionCode: 'arrangement_required',
  lines: const [
    YorksV1MaterialRequestLine(
      id: 'submitted-line',
      displayOrder: 1,
      source: YorksV1MaterialRequestLineSource.boq,
      sourceBoqGroupId: 'group-1',
      sourceBoqRowId: 'row-1',
      description: 'Flexible duct',
      quantity: '2',
      unit: 'Nos',
      brandOrigin: 'Yorks',
    ),
  ],
);

YorksV1MaterialRequest _summaryProjection({
  required String id,
  required YorksV1MaterialRequestState state,
  required int itemCount,
  DateTime? scheduledDate,
  double currentActionAgeHours = 0,
  bool requiredOnSiteOverdue = false,
  bool actorCanAct = false,
  List<YorksV1MaterialRequestExceptionCode> exceptionCodes = const [],
}) => YorksV1MaterialRequestSummary(
  id: id,
  projectId: _projectId,
  projectReference: 'YRA-322',
  projectName: 'Al Dhafra Grid Substation HVAC Works',
  scopeId: 'scope-common',
  scopeName: 'Common / All Buildings',
  state: state,
  recordVersion: 2,
  createdAt: DateTime.utc(2026, 8, 9),
  updatedAt: DateTime.utc(2026, 8, 10),
  timing: scheduledDate == null
      ? YorksV1MaterialRequestTiming.normal
      : YorksV1MaterialRequestTiming.scheduled,
  scheduledDate: scheduledDate,
  itemCount: itemCount,
  requestNumber: 'MR-${state.wireValue}',
  currentActionOwnerRole: 'procurement',
  currentActionCode: 'arrangement_required',
  currentActionAgeHours: currentActionAgeHours,
  requiredOnSiteOverdue: requiredOnSiteOverdue,
  actorCanAct: actorCanAct,
  exceptionCodes: exceptionCodes,
  workAssignment: YorksV1MaterialRequestWorkAssignment(
    requestId: id,
    assignmentVersion: 0,
    canManage: false,
  ),
).toRegisterProjection();

YorksV1MaterialRequest _requestVariant({
  required String id,
  YorksV1MaterialRequestState state =
      YorksV1MaterialRequestState.approvedForArrangement,
  List<YorksV1MaterialRequestComment> comments = const [],
  bool canDecideRequest = false,
  bool canEditBeforeApproval = false,
}) => YorksV1MaterialRequest(
  id: id,
  projectId: _submittedRequest.projectId,
  projectReference: _submittedRequest.projectReference,
  projectName: _submittedRequest.projectName,
  scopeId: _submittedRequest.scopeId,
  scopeName: _submittedRequest.scopeName,
  state: state,
  recordVersion: _submittedRequest.recordVersion,
  createdAt: _submittedRequest.createdAt,
  updatedAt: _submittedRequest.updatedAt,
  timing: _submittedRequest.timing,
  requestNumber: _submittedRequest.requestNumber,
  title: _submittedRequest.title,
  requesterDisplayName: _submittedRequest.requesterDisplayName,
  requesterProjectRole: _submittedRequest.requesterProjectRole,
  currentActionOwnerRole:
      state == YorksV1MaterialRequestState.awaitingRequestApproval
      ? 'project_engineer'
      : state == YorksV1MaterialRequestState.closed
      ? null
      : _submittedRequest.currentActionOwnerRole,
  currentActionCode:
      state == YorksV1MaterialRequestState.awaitingRequestApproval
      ? 'request_approval_required'
      : state == YorksV1MaterialRequestState.closed
      ? null
      : _submittedRequest.currentActionCode,
  canDecideRequest: canDecideRequest,
  canEditBeforeApproval: canEditBeforeApproval,
  comments: comments,
  lines: _submittedRequest.lines,
);

List<YorksV1MaterialRequestComment> _discussionComments(String requestId) =>
    List.generate(
      9,
      (index) => YorksV1MaterialRequestComment(
        id: 'comment-$index',
        requestId: requestId,
        body: 'Discussion comment ${index + 1}',
        authorAuthUserId: 'author-$index',
        authorRole: 'project_engineer',
        authorExactRole: 'project_engineer',
        authorDisplayName: 'Engineer ${index + 1}',
        createdAt: DateTime.utc(2026, 8, 14, 8, index),
        mentions: const [],
      ),
    );

final _draftRequest = YorksV1MaterialRequest(
  id: 'mobile-mr-draft-record',
  projectId: _projectId,
  projectReference: 'YRA-322',
  projectName: 'Al Dhafra Grid Substation HVAC Works',
  scopeId: 'scope-common',
  scopeName: 'Common / All Buildings',
  state: YorksV1MaterialRequestState.draft,
  recordVersion: 1,
  createdAt: DateTime.utc(2026, 8, 9),
  updatedAt: DateTime.utc(2026, 8, 9),
  timing: YorksV1MaterialRequestTiming.normal,
  title: 'Private draft',
  lines: const [],
);

final _urgentDraftRequest = YorksV1MaterialRequest(
  id: _draftId,
  projectId: _projectId,
  projectReference: 'YRA-322',
  projectName: 'Al Dhafra Grid Substation HVAC Works',
  scopeId: 'scope-common',
  scopeName: 'Common / All Buildings',
  state: YorksV1MaterialRequestState.draft,
  recordVersion: 3,
  createdAt: DateTime.utc(2026, 8, 9),
  updatedAt: DateTime.utc(2026, 8, 24),
  timing: YorksV1MaterialRequestTiming.urgent,
  title: 'Urgent existing draft',
  lines: const [],
);

YorksV1RuntimeConfiguration _runtimeConfiguration({
  String defaultTiming = 'normal',
  bool urgentEnabled = true,
}) => YorksV1RuntimeConfiguration(
  schemaVersion: 'yorks_v1_runtime_configuration_v1',
  publishedVersion: 8,
  publishedLabel: 'v1.8',
  publishedAt: DateTime.utc(2026, 8, 24),
  defaultTiming: defaultTiming,
  urgentEnabled: urgentEnabled,
  allowAuthorizedCreatorSelfApproval: true,
  requireExternalSourceReadiness: false,
  pushEnabled: true,
);

class _MaterialRequestRepositoryFixture
    implements YorksV1MaterialRequestRepository {
  _MaterialRequestRepositoryFixture({this.serverRequest});

  final YorksV1MaterialRequest? serverRequest;
  int saveAndSubmitCount = 0;
  final List<YorksV1AddMaterialRequestCommentInput> addCommentInputs = [];
  List<YorksV1MaterialRequestMention> mentionCandidates = const [];
  List<YorksV1MaterialRequestInventorySuggestion> inventorySuggestions =
      const [];
  String? lastSearchProjectId;
  String? lastSearchScopeId;

  @override
  Future<List<YorksV1MaterialRequestComment>> addComment(
    YorksV1AddMaterialRequestCommentInput input,
  ) async {
    addCommentInputs.add(input);
    return const [];
  }

  @override
  Future<YorksV1MaterialRequest> decideRequest(
    YorksV1DecideMaterialRequestInput input,
  ) async => _submittedRequest;

  @override
  Future<List<YorksV1MaterialRequestMention>> listMentionCandidates(
    String requestId,
  ) async => mentionCandidates;

  @override
  Future<List<YorksV1MaterialRequestInventorySuggestion>> searchInventory({
    required String projectId,
    required String scopeId,
    required String query,
  }) async {
    lastSearchProjectId = projectId;
    lastSearchScopeId = scopeId;
    return inventorySuggestions
        .where(
          (item) =>
              item.description.toLowerCase().contains(query.toLowerCase()),
        )
        .toList(growable: false);
  }

  @override
  Future<YorksV1MaterialRequest> updateForApproval(
    YorksV1UpdateMaterialRequestForApprovalInput input,
  ) async => _submittedRequest;
  @override
  Future<YorksV1MaterialRequest> cancel(
    YorksV1CancelMaterialRequestInput input,
  ) async => _submittedRequest;

  @override
  Future<YorksV1MaterialRequest> close(
    YorksV1CloseMaterialRequestInput input,
  ) async => _submittedRequest;

  @override
  Future<void> deleteDraft(String requestId) async {}

  @override
  Future<YorksV1MaterialRequest> getRequest(String requestId) async {
    if (serverRequest != null) return serverRequest!;
    throw const YorksV1DomainException(
      YorksV1DomainErrorCode.unauthorized,
      serverCode: '42501',
    );
  }

  @override
  Future<YorksV1MaterialRequestDocumentModel> getDocumentModel(
    String requestId,
  ) async => YorksV1MaterialRequestDocumentModel.fromRequest(_submittedRequest);

  @override
  Future<List<YorksV1MaterialRequestProjectOption>> listDraftProjects() async =>
      const [];

  @override
  Future<List<YorksV1MaterialRequest>> listRequests({
    String? projectId,
  }) async => const [];

  @override
  Future<List<YorksV1MaterialRequestScopeOption>> listScopes(
    String projectId,
  ) async => const [];

  @override
  Future<YorksV1MaterialRequest> saveAndSubmit(
    YorksV1MaterialRequestDraft draft,
  ) async {
    saveAndSubmitCount++;
    return _submittedRequest;
  }

  @override
  Future<YorksV1MaterialRequest> saveDraft(
    YorksV1SaveMaterialRequestDraftInput input,
  ) async => _draftRequest;

  @override
  Future<YorksV1MaterialRequest> submit(
    YorksV1SubmitMaterialRequestInput input,
  ) async => _submittedRequest;
}

class _BoqRepositoryFixture implements YorksV1BoqRepository {
  static final _group = YorksV1BoqGroup(
    id: 'mobile-mr-boq-group',
    projectId: _projectId,
    name: 'Air outlets',
    worksheetTitle: 'Air outlets',
    displayOrder: 1,
    isCustom: false,
    isArchived: false,
    version: 1,
    rowCount: 12,
    columnCount: 3,
    updatedAt: DateTime.utc(2026, 8, 9),
    scopeId: 'scope-common',
    scopeKind: 'common',
    scopeName: 'Common / All Buildings',
  );

  static final _groups = [
    _group,
    for (final entry in <({String name, int rows})>[
      (name: 'Ventilation Fans', rows: 8),
      (name: 'MFD, MSFD, MSD, MVCD & VCD', rows: 15),
      (name: 'Air Inlet & Outlet', rows: 18),
      (name: 'Cable Tray', rows: 0),
    ])
      YorksV1BoqGroup(
        id: 'mobile-mr-boq-${entry.rows}-${entry.name.length}',
        projectId: _projectId,
        name: entry.name,
        worksheetTitle: entry.name,
        displayOrder: _groupsDisplayOrder(entry.name),
        isCustom: false,
        isArchived: false,
        version: 1,
        rowCount: entry.rows,
        columnCount: 3,
        updatedAt: DateTime.utc(2026, 8, 9),
        scopeId: 'scope-common',
        scopeKind: 'common',
        scopeName: 'Common / All Buildings',
      ),
  ];

  static final _worksheet = YorksV1BoqWorksheet(
    group: _group,
    columns: const [
      YorksV1BoqColumn(
        id: 'description',
        heading: 'Item description',
        displayOrder: 1,
        canonicalField: YorksV1BoqCanonicalField.description,
      ),
      YorksV1BoqColumn(
        id: 'quantity',
        heading: 'Qty.',
        displayOrder: 2,
        canonicalField: YorksV1BoqCanonicalField.quantity,
      ),
      YorksV1BoqColumn(
        id: 'unit',
        heading: 'Unit',
        displayOrder: 3,
        canonicalField: YorksV1BoqCanonicalField.unit,
      ),
    ],
    rows: [
      YorksV1BoqRow(
        id: 'mobile-mr-boq-row',
        displayOrder: 1,
        values: const {
          'description': 'Flexible duct',
          'quantity': '2',
          'unit': 'Nos',
        },
        canonicalValues: const {
          'description': 'Flexible duct',
          'quantity': '2',
          'unit': 'Nos',
        },
      ),
    ],
  );

  @override
  Future<YorksV1BoqGroup> archiveGroup(
    YorksV1ArchiveBoqGroupInput input,
  ) async => _group;

  @override
  Future<YorksV1BoqGroup> assignLegacyGroupScope(
    YorksV1AssignLegacyBoqGroupScopeInput input,
  ) async => _group;

  @override
  Future<YorksV1BoqGroup> createCustomGroup(
    YorksV1CreateBoqGroupInput input,
  ) async => _group;

  @override
  Future<YorksV1BoqGroup> renameGroup(YorksV1RenameBoqGroupInput input) async =>
      _group;

  @override
  Future<YorksV1BoqGroup> restoreGroup(
    YorksV1RestoreBoqGroupInput input,
  ) async => _group;

  @override
  Future<YorksV1BoqWorksheet> getWorksheet(String groupId) async => _worksheet;

  @override
  Future<YorksV1BoqWorksheet> importWorksheet(
    YorksV1ImportBoqWorksheetInput input,
  ) async => _worksheet;

  @override
  Future<List<YorksV1BoqGroup>> listGroups(String projectId) async => _groups;

  @override
  Future<List<YorksV1BoqFolderManagementItem>> listFolderManagement(
    String projectId, {
    required String scopeId,
    bool includeArchived = true,
  }) async => [
    for (final group in _groups)
      if (group.scopeId == scopeId && (includeArchived || !group.isArchived))
        YorksV1BoqFolderManagementItem(
          group: group,
          isSystemDefault: !group.isCustom,
          canRename: !group.isArchived,
          canArchive: group.isCustom && !group.isArchived,
          canRestore: group.isCustom && group.isArchived,
        ),
  ];

  @override
  Future<List<YorksV1BoqGroup>> listGroupsForScope(
    String projectId, {
    String? scopeId,
  }) async => _groups;

  @override
  Future<YorksV1BoqWorksheet> saveWorksheet(
    YorksV1SaveBoqWorksheetInput input,
  ) async => _worksheet;
}

class _DesktopBoqRepositoryFixture extends _BoqRepositoryFixture {
  @override
  Future<List<YorksV1BoqGroup>> listGroups(String projectId) async => [
    _BoqRepositoryFixture._group,
  ];

  @override
  Future<List<YorksV1BoqGroup>> listGroupsForScope(
    String projectId, {
    String? scopeId,
  }) async => [_BoqRepositoryFixture._group];
}

class _EmptyBoqRepositoryFixture extends _BoqRepositoryFixture {
  @override
  Future<List<YorksV1BoqGroup>> listGroups(String projectId) async => const [];

  @override
  Future<List<YorksV1BoqGroup>> listGroupsForScope(
    String projectId, {
    String? scopeId,
  }) async => const [];
}

int _groupsDisplayOrder(String name) => switch (name) {
  'Ventilation Fans' => 2,
  'MFD, MSFD, MSD, MVCD & VCD' => 3,
  'Air Inlet & Outlet' => 4,
  _ => 5,
};
