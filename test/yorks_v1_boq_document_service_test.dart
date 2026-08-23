import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_boq.dart';
import 'package:material_ledger/shared/services/yorks_v1_boq_document_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('BOQ folder print builds a valid role-safe PDF', () async {
    final bytes = await const YorksV1BoqDocumentService().buildPdf([
      _worksheet,
    ], canViewCommercials: false);

    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });

  test('unsaved BOQ output is a visibly distinct draft document', () async {
    const service = YorksV1BoqDocumentService();
    final generatedAt = DateTime.utc(2026, 8, 23, 8, 30);
    final controlled = await service.buildPdf(
      [_worksheet],
      canViewCommercials: false,
      generatedAt: generatedAt,
    );
    final draft = await service.buildPdf(
      [_worksheet],
      canViewCommercials: false,
      draftCopy: true,
      generatedAt: generatedAt,
    );

    expect(ascii.decode(draft.take(5).toList()), '%PDF-');
    expect(draft, isNot(orderedEquals(controlled)));
    expect(draft.length, greaterThan(controlled.length));
  });
}

final _worksheet = YorksV1BoqWorksheet(
  group: YorksV1BoqGroup(
    id: 'group-1',
    projectId: 'project-1',
    name: 'Ducting Materials',
    worksheetTitle: 'Ducting Materials',
    displayOrder: 1,
    isCustom: false,
    isArchived: false,
    version: 1,
    rowCount: 1,
    columnCount: 2,
    scopeName: 'Building A',
    updatedAt: DateTime.utc(2026, 8, 23),
  ),
  columns: const [
    YorksV1BoqColumn(
      id: 'description',
      heading: 'Item Description',
      displayOrder: 1,
      canonicalField: YorksV1BoqCanonicalField.description,
    ),
    YorksV1BoqColumn(
      id: 'unit-cost',
      heading: 'Unit Cost',
      displayOrder: 2,
      canonicalField: YorksV1BoqCanonicalField.unitCost,
    ),
  ],
  rows: [
    YorksV1BoqRow(
      id: 'row-1',
      displayOrder: 1,
      values: {'description': 'GI duct', 'unit-cost': '14.250'},
      canonicalValues: {'description': 'GI duct', 'unit_cost': '14.250'},
    ),
  ],
);
