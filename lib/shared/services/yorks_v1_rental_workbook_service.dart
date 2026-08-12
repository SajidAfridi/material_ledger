import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/yorks_v1_boq_workbook.dart';
import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_rental.dart';
import '../models/yorks_v1_rental_workbook.dart';
import 'yorks_v1_boq_workbook_service.dart';

abstract interface class YorksV1RentalWorkbookFileService {
  Future<YorksV1RentalSelectedWorkbook?> selectWorkbook();

  Future<bool> saveImportTemplate();

  Future<bool> saveExport({
    required Uint8List bytes,
    required String suggestedName,
  });
}

class YorksV1PlatformRentalWorkbookFileService
    implements YorksV1RentalWorkbookFileService {
  const YorksV1PlatformRentalWorkbookFileService();

  static const _mime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  static const _type = XTypeGroup(
    label: 'Excel workbook',
    extensions: ['xlsx'],
    mimeTypes: [_mime],
  );

  @override
  Future<YorksV1RentalSelectedWorkbook?> selectWorkbook() async {
    final file = await openFile(acceptedTypeGroups: const [_type]);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (!file.name.toLowerCase().endsWith('.xlsx') ||
        bytes.isEmpty ||
        bytes.lengthInBytes > 15 * 1024 * 1024) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    return YorksV1RentalSelectedWorkbook(
      fileName: _fileName(file.name),
      bytes: bytes,
    );
  }

  @override
  Future<bool> saveImportTemplate() => saveExport(
    bytes: const YorksV1RentalWorkbookCodec().buildImportTemplate(),
    suggestedName: 'Yorks_Rental_Properties_Import_Template.xlsx',
  );

  @override
  Future<bool> saveExport({
    required Uint8List bytes,
    required String suggestedName,
  }) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [_type],
    );
    if (location == null) return false;
    await XFile.fromData(
      bytes,
      name: suggestedName,
      mimeType: _mime,
    ).saveTo(location.path);
    return true;
  }

  static String _fileName(String value) {
    final normalized = value.replaceAll('\\', '/');
    return normalized.substring(normalized.lastIndexOf('/') + 1);
  }
}

class YorksV1RentalWorkbookCodec {
  const YorksV1RentalWorkbookCodec();

  static const _uuid = Uuid();
  static const propertySheet = 'Rental Properties';
  static const paymentSheet = 'Payment History';
  static const chequeSheet = 'Cheque Register';
  static const instructionsSheet = 'Instructions';
  static const listsSheet = 'Lists';

  static const propertyHeaders = [
    'Import Action *',
    'Unit Code *',
    'Property Name *',
    'Property Type *',
    'Property / Municipality No.',
    'Location *',
    'Occupancy *',
    'Tenant / Company Name',
    'Tenant Contact',
    'Tenant Email',
    'Trade Licence No.',
    'Contract No.',
    'Contract Type',
    'Contract Status',
    'Contract Signed Date',
    'Lease Start',
    'Lease End',
    'Monthly Rent AED',
    'Monthly Due Day',
    'Grace Period Days',
    'Security Deposit AED',
    'Default Payment Method',
    'Payment Frequency',
    'No. of Contract Cheques',
    'Annual Escalation %',
    'Renewal Notice Days',
    'Notes',
  ];
  static const paymentHeaders = [
    'Unit Code *',
    'Rent Period *',
    'Amount Received AED *',
    'Payment Date *',
    'Payment Method *',
    'Receipt / Bank / Cheque Reference',
    'Payment Note',
  ];
  static const chequeHeaders = [
    'Unit Code *',
    'Cheque Type *',
    'Cheque Number *',
    'Bank *',
    'Linked Rent Period *',
    'Cheque Date *',
    'Amount AED *',
    'Status *',
    'Note',
  ];

  YorksV1RentalImportPreview preview({
    required YorksV1RentalSelectedWorkbook selected,
    required YorksV1RentalPortfolio portfolio,
  }) {
    final workbook = const YorksV1BoqWorkbookCodec().decode(
      bytes: selected.bytes,
      fileName: selected.fileName,
    );
    final issues = <YorksV1RentalImportIssue>[];
    final properties = _propertyRows(
      _sheet(workbook, propertySheet, issues),
      portfolio,
      issues,
    );
    final knownCodes = <String>{
      for (final property in portfolio.properties)
        property.unitCode.trim().toUpperCase(),
      for (final row in properties)
        if (!row.hasError) row.payload['unit_code']!.toString(),
    };
    final payments = _paymentRows(
      _sheet(workbook, paymentSheet, issues),
      knownCodes,
      issues,
    );
    final cheques = _chequeRows(
      _sheet(workbook, chequeSheet, issues),
      knownCodes,
      issues,
    );
    return YorksV1RentalImportPreview(
      fileName: selected.fileName,
      commandId: _uuid.v4(),
      properties: properties,
      payments: payments,
      cheques: cheques,
      issues: issues,
    );
  }

  Uint8List buildImportTemplate() => _WorkbookWriter.encode({
    instructionsSheet: [
      ['Yorks Rental Properties Import'],
      [
        'Preview and resolve every ERROR before Confirm Import. Nothing changes during preview.',
      ],
      [
        'Use Create only for a new Unit Code and Update only for an existing one.',
      ],
      [
        'Dates: YYYY-MM-DD. Amounts: positive numbers without currency symbols.',
      ],
      [
        'CDC/PDC payments require a reference. Do not duplicate cheque numbers.',
      ],
    ],
    propertySheet: [propertyHeaders],
    paymentSheet: [paymentHeaders],
    chequeSheet: [chequeHeaders],
    listsSheet: const [
      [
        'Import Action',
        'Property Type',
        'Occupancy',
        'Contract Type',
        'Contract Status',
        'Payment Method',
        'Payment Frequency',
        'Cheque Type',
        'Cheque Status',
      ],
      [
        'Create',
        'Shop',
        'Occupied',
        'Tenancy Contract',
        'Draft',
        'Bank Transfer',
        'Monthly',
        'CDC',
        'Scheduled',
      ],
      [
        'Update',
        'Warehouse',
        'Vacant',
        'Lease',
        'Active',
        'Cash',
        'Quarterly',
        'PDC',
        'Received',
      ],
      ['', 'Office', '', '', 'Expired', 'CDC', 'Annual', '', 'Deposited'],
      ['', 'Villa', '', '', 'Terminated', 'PDC', '', '', 'Cleared'],
      ['', 'Labour Camp', '', '', 'Renewed', 'Other', '', '', 'Returned'],
      ['', 'Other', '', '', '', '', '', '', 'Cancelled'],
    ],
  });

  Uint8List buildExport({
    required YorksV1RentalExportRegister register,
    required Map<String, dynamic> data,
  }) {
    final key = switch (register) {
      YorksV1RentalExportRegister.propertyLease => 'properties',
      YorksV1RentalExportRegister.rentSchedule => 'periods',
      YorksV1RentalExportRegister.payments => 'payments',
      YorksV1RentalExportRegister.cheques => 'cheques',
      YorksV1RentalExportRegister.leaseExpiry => 'lease_expiry',
    };
    final title = switch (register) {
      YorksV1RentalExportRegister.propertyLease => 'Property & Lease Register',
      YorksV1RentalExportRegister.rentSchedule => 'Rent Schedule & Outstanding',
      YorksV1RentalExportRegister.payments => 'Payment Receipt Register',
      YorksV1RentalExportRegister.cheques => 'CDC PDC Register',
      YorksV1RentalExportRegister.leaseExpiry => 'Lease Expiry & Renewal',
    };
    final values = data[key];
    final rows = values is List
        ? values
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList()
        : <Map<String, dynamic>>[];
    final headers = rows.isEmpty
        ? <String>['No records']
        : rows.first.keys.toList();
    return _WorkbookWriter.encode({
      title: [
        headers,
        for (final row in rows)
          [for (final header in headers) _cell(row[header])],
      ],
    });
  }

  YorksV1BoqWorkbookSheet? _sheet(
    YorksV1BoqParsedWorkbook workbook,
    String name,
    List<YorksV1RentalImportIssue> issues,
  ) {
    for (final sheet in workbook.sheets) {
      if (sheet.name.trim().toLowerCase() == name.toLowerCase()) return sheet;
    }
    issues.add(
      YorksV1RentalImportIssue(
        sheet: name,
        rowNumber: 1,
        message: 'Required worksheet “$name” is missing.',
      ),
    );
    return null;
  }

  List<YorksV1RentalImportRow> _propertyRows(
    YorksV1BoqWorkbookSheet? sheet,
    YorksV1RentalPortfolio portfolio,
    List<YorksV1RentalImportIssue> allIssues,
  ) {
    if (sheet == null) return const [];
    final table = _table(sheet, propertyHeaders, allIssues);
    final existing = {
      for (final property in portfolio.properties)
        property.unitCode.trim().toUpperCase(): property,
    };
    final seen = <String>{};
    return [
      for (final entry in table.entries)
        _propertyRow(entry.key, entry.value, existing, seen, allIssues),
    ];
  }

  YorksV1RentalImportRow _propertyRow(
    int rowNumber,
    Map<String, String> row,
    Map<String, YorksV1RentalProperty> existing,
    Set<String> seen,
    List<YorksV1RentalImportIssue> allIssues,
  ) {
    final issues = <YorksV1RentalImportIssue>[];
    void error(String message) => issues.add(
      YorksV1RentalImportIssue(
        sheet: propertySheet,
        rowNumber: rowNumber,
        message: message,
      ),
    );
    final action = row['Import Action *']!.trim().toLowerCase();
    final code = row['Unit Code *']!.trim().toUpperCase();
    if (!{'create', 'update'}.contains(action)) {
      error('Import Action must be Create or Update.');
    }
    if (code.isEmpty) error('Unit Code is required.');
    if (!seen.add(code)) error('Unit Code is duplicated in this workbook.');
    if (action == 'create' && existing.containsKey(code)) {
      error('Create cannot use an existing Unit Code. Choose Update.');
    }
    if (action == 'update' && !existing.containsKey(code)) {
      error('Update requires an existing Unit Code.');
    }
    for (final field in [
      'Property Name *',
      'Property Type *',
      'Location *',
      'Occupancy *',
    ]) {
      if (row[field]!.trim().isEmpty) {
        error('${field.replaceAll(' *', '')} is required.');
      }
    }
    final occupied = row['Occupancy *']!.trim().toLowerCase() == 'occupied';
    if (occupied &&
        (row['Tenant / Company Name']!.trim().isEmpty ||
            row['Contract No.']!.trim().isEmpty ||
            row['Lease Start']!.trim().isEmpty ||
            row['Lease End']!.trim().isEmpty)) {
      error(
        'Occupied properties require tenant, contract number, lease start and lease end.',
      );
    }
    final monthlyRent = _number(row['Monthly Rent AED']);
    final dueDay = _integer(row['Monthly Due Day'], fallback: 1);
    if (monthlyRent < 0) error('Monthly Rent cannot be negative.');
    if (dueDay < 1 || dueDay > 31) {
      error('Monthly Due Day must be between 1 and 31.');
    }
    allIssues.addAll(issues);
    final existingProperty = existing[code];
    return YorksV1RentalImportRow(
      sheet: propertySheet,
      rowNumber: rowNumber,
      action: action,
      label: '$code · ${row['Property Name *']}',
      issues: issues,
      payload: {
        'source_row': rowNumber,
        'action': action,
        if (existingProperty != null) 'property_id': existingProperty.id,
        if (existingProperty?.leaseId != null)
          'lease_id': existingProperty!.leaseId,
        if (existingProperty != null)
          'expected_version': existingProperty.recordVersion,
        'unit_code': code,
        'property_name': row['Property Name *']!.trim(),
        'property_type': _wire(row['Property Type *']!),
        'municipality_number': _null(row['Property / Municipality No.']),
        'location': row['Location *']!.trim(),
        'occupied': occupied,
        'tenant_name': _null(row['Tenant / Company Name']),
        'contact_number': _null(row['Tenant Contact']),
        'email': _null(row['Tenant Email']),
        'trade_licence_number': _null(row['Trade Licence No.']),
        'contract_number': _null(row['Contract No.']),
        'contract_type': _wire(
          row['Contract Type']!.isEmpty
              ? 'Tenancy Contract'
              : row['Contract Type']!,
        ),
        'contract_status': _wire(
          row['Contract Status']!.isEmpty ? 'Draft' : row['Contract Status']!,
        ),
        'signed_date': _date(row['Contract Signed Date']),
        'lease_start': _date(row['Lease Start']),
        'lease_end': _date(row['Lease End']),
        'monthly_rent': monthlyRent,
        'monthly_due_day': dueDay,
        'grace_period_days': _integer(row['Grace Period Days'], fallback: 5),
        'security_deposit': _number(row['Security Deposit AED']),
        'default_payment_method': _wire(
          row['Default Payment Method']!.isEmpty
              ? 'Bank Transfer'
              : row['Default Payment Method']!,
        ),
        'payment_frequency': _wire(
          row['Payment Frequency']!.isEmpty
              ? 'Monthly'
              : row['Payment Frequency']!,
        ),
        'contract_cheque_count': _integer(row['No. of Contract Cheques']),
        'annual_escalation_percent': _number(row['Annual Escalation %']),
        'renewal_notice_days': _integer(
          row['Renewal Notice Days'],
          fallback: 90,
        ),
        'lease_notes': _null(row['Notes']),
      },
    );
  }

  List<YorksV1RentalImportRow> _paymentRows(
    YorksV1BoqWorkbookSheet? sheet,
    Set<String> knownCodes,
    List<YorksV1RentalImportIssue> allIssues,
  ) {
    final seenReferences = <String>{};
    final seenReceipts = <String>{};
    return _simpleRows(sheet, paymentHeaders, paymentSheet, allIssues, (
      rowNumber,
      row,
      issues,
    ) {
      final code = row['Unit Code *']!.trim().toUpperCase();
      final amount = _number(row['Amount Received AED *']);
      final method = _wire(row['Payment Method *']!);
      final rentPeriod = _date(row['Rent Period *']);
      final paymentDate = _date(row['Payment Date *']);
      final reference = row['Receipt / Bank / Cheque Reference']!.trim();
      if (!knownCodes.contains(code)) issues.add('Unknown Unit Code.');
      if (rentPeriod == null) {
        issues.add('Rent Period must be a valid date.');
      }
      if (amount <= 0) {
        issues.add('Amount Received must be greater than zero.');
      }
      if (paymentDate == null) {
        issues.add('Payment Date must be valid.');
      }
      if (!{'bank_transfer', 'cash', 'cdc', 'pdc', 'other'}.contains(method)) {
        issues.add('Payment Method is not supported.');
      }
      if ({'cdc', 'pdc'}.contains(method) && reference.isEmpty) {
        issues.add('CDC/PDC payments require a reference.');
      }
      if (reference.isNotEmpty &&
          !seenReferences.add(reference.toLowerCase())) {
        issues.add('Payment reference is duplicated in this workbook.');
      }
      final receiptIdentity = [
        code,
        rentPeriod ?? '',
        amount.toStringAsFixed(2),
        paymentDate ?? '',
        method,
        reference.toLowerCase(),
      ].join('|');
      if (!seenReceipts.add(receiptIdentity)) {
        issues.add('The same rent receipt is duplicated in this workbook.');
      }
      return {
        'source_row': rowNumber,
        'unit_code': code,
        'rent_period': rentPeriod,
        'amount_received': amount,
        'payment_date': paymentDate,
        'payment_method': method,
        'reference': _null(reference),
        'note': _null(row['Payment Note']),
      };
    });
  }

  List<YorksV1RentalImportRow> _chequeRows(
    YorksV1BoqWorkbookSheet? sheet,
    Set<String> knownCodes,
    List<YorksV1RentalImportIssue> allIssues,
  ) {
    final seen = <String>{};
    return _simpleRows(sheet, chequeHeaders, chequeSheet, allIssues, (
      rowNumber,
      row,
      issues,
    ) {
      final code = row['Unit Code *']!.trim().toUpperCase();
      final bank = row['Bank *']!.trim();
      final number = row['Cheque Number *']!.trim();
      if (!knownCodes.contains(code)) issues.add('Unknown Unit Code.');
      if (number.isEmpty || bank.isEmpty) {
        issues.add('Cheque Number and Bank are required.');
      }
      if (!seen.add('$code|${bank.toLowerCase()}|${number.toLowerCase()}')) {
        issues.add('Cheque is duplicated in this workbook.');
      }
      if (_number(row['Amount AED *']) <= 0) {
        issues.add('Cheque amount must be greater than zero.');
      }
      if (_date(row['Cheque Date *']) == null) {
        issues.add('Cheque Date must be valid.');
      }
      return {
        'source_row': rowNumber,
        'unit_code': code,
        'cheque_type': _wire(row['Cheque Type *']!),
        'cheque_number': number,
        'bank_name': bank,
        'rent_period': _date(row['Linked Rent Period *']),
        'cheque_date': _date(row['Cheque Date *']),
        'amount': _number(row['Amount AED *']),
        'status': _wire(row['Status *']!),
        'note': _null(row['Note']),
      };
    });
  }

  List<YorksV1RentalImportRow> _simpleRows(
    YorksV1BoqWorkbookSheet? sheet,
    List<String> headers,
    String sheetName,
    List<YorksV1RentalImportIssue> allIssues,
    Map<String, Object?> Function(int, Map<String, String>, List<String>) build,
  ) {
    if (sheet == null) return const [];
    final table = _table(sheet, headers, allIssues);
    return [
      for (final entry in table.entries)
        (() {
          final messages = <String>[];
          final payload = build(entry.key, entry.value, messages);
          final issues = [
            for (final message in messages)
              YorksV1RentalImportIssue(
                sheet: sheetName,
                rowNumber: entry.key,
                message: message,
              ),
          ];
          allIssues.addAll(issues);
          return YorksV1RentalImportRow(
            sheet: sheetName,
            rowNumber: entry.key,
            action: 'append',
            label: payload['unit_code']?.toString() ?? sheetName,
            payload: payload,
            issues: issues,
          );
        })(),
    ];
  }

  Map<int, Map<String, String>> _table(
    YorksV1BoqWorkbookSheet sheet,
    List<String> requiredHeaders,
    List<YorksV1RentalImportIssue> issues,
  ) {
    if (sheet.rows.isEmpty) return const {};
    final header = sheet.rows.first.map((value) => value.trim()).toList();
    for (final required in requiredHeaders) {
      if (!header.contains(required)) {
        issues.add(
          YorksV1RentalImportIssue(
            sheet: sheet.name,
            rowNumber: 1,
            message: 'Required column “$required” is missing.',
          ),
        );
      }
    }
    final result = <int, Map<String, String>>{};
    for (var index = 1; index < sheet.rows.length; index++) {
      final source = sheet.rows[index];
      if (source.every((cell) => cell.trim().isEmpty)) continue;
      result[index + 1] = {
        for (final required in requiredHeaders)
          required: _sourceValue(header, source, required),
      };
    }
    return result;
  }

  static String _sourceValue(
    List<String> header,
    List<String> source,
    String required,
  ) {
    final column = header.indexOf(required);
    return column >= 0 && column < source.length ? source[column].trim() : '';
  }

  static String? _null(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
  static String _wire(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  static double _number(String? value) =>
      double.tryParse((value ?? '').replaceAll(',', '').trim()) ?? 0;
  static int _integer(String? value, {int fallback = 0}) =>
      int.tryParse((value ?? '').trim()) ?? fallback;
  static String? _date(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final direct = DateTime.tryParse(text);
    if (direct != null) return DateFormat('yyyy-MM-dd').format(direct);
    final serial = double.tryParse(text);
    if (serial != null && serial > 0) {
      return DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(1899, 12, 30).add(Duration(days: serial.floor())));
    }
    for (final pattern in ['dd/MM/yyyy', 'MM/dd/yyyy', 'dd MMM yyyy']) {
      try {
        return DateFormat(
          'yyyy-MM-dd',
        ).format(DateFormat(pattern).parseStrict(text));
      } catch (_) {}
    }
    return null;
  }

  static String _cell(Object? value) {
    if (value == null) return '';
    if (value is Map || value is List) return jsonEncode(value);
    return value.toString();
  }
}

class _WorkbookWriter {
  static Uint8List encode(Map<String, List<List<String>>> sheets) {
    final names = sheets.keys.toList();
    final archive = Archive()
      ..addFile(
        ArchiveFile.string('[Content_Types].xml', _contentTypes(names.length)),
      )
      ..addFile(ArchiveFile.string('_rels/.rels', _rootRels))
      ..addFile(ArchiveFile.string('xl/workbook.xml', _workbook(names)))
      ..addFile(
        ArchiveFile.string(
          'xl/_rels/workbook.xml.rels',
          _workbookRels(names.length),
        ),
      )
      ..addFile(ArchiveFile.string('xl/styles.xml', _styles));
    for (var index = 0; index < names.length; index++) {
      archive.addFile(
        ArchiveFile.string(
          'xl/worksheets/sheet${index + 1}.xml',
          _sheet(sheets[names[index]]!),
        ),
      );
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static String _sheet(List<List<String>> rows) {
    final out = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews><sheetData>',
    );
    for (var r = 0; r < rows.length; r++) {
      out.write('<row r="${r + 1}">');
      for (var c = 0; c < rows[r].length; c++) {
        final value = _xml(rows[r][c]);
        out.write(
          '<c r="${_column(c)}${r + 1}" s="${r == 0 ? 1 : 2}" t="inlineStr"><is><t xml:space="preserve">$value</t></is></c>',
        );
      }
      out.write('</row>');
    }
    out.write(
      '</sheetData><autoFilter ref="A1:${_column(rows.fold<int>(1, (max, row) => row.length > max ? row.length : max) - 1)}${rows.isEmpty ? 1 : rows.length}"/></worksheet>',
    );
    return out.toString();
  }

  static String _contentTypes(int count) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>${[for (var i = 1; i <= count; i++) '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}</Types>';
  static const _rootRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>';
  static String _workbook(List<String> names) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>${[for (var i = 0; i < names.length; i++) '<sheet name="${_xml(names[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}</sheets></workbook>';
  static String _workbookRels(int count) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${[for (var i = 1; i <= count; i++) '<Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>'].join()}<Relationship Id="rId${count + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>';
  static const _styles =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="2"><font><sz val="11"/><name val="Aptos"/></font><font><b/><color rgb="FFFFFFFF"/><sz val="11"/><name val="Aptos"/></font></fonts><fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF12365F"/></patternFill></fill></fills><borders count="2"><border/><border><left style="thin"><color rgb="FFD7E0EB"/></left><right style="thin"><color rgb="FFD7E0EB"/></right><top style="thin"><color rgb="FFD7E0EB"/></top><bottom style="thin"><color rgb="FFD7E0EB"/></bottom></border></borders><cellStyleXfs count="1"><xf/></cellStyleXfs><cellXfs count="3"><xf/><xf fontId="1" fillId="2" borderId="1" applyFont="1" applyFill="1" applyBorder="1"/><xf borderId="1" applyBorder="1"/></cellXfs></styleSheet>';
  static String _column(int index) {
    var value = index + 1;
    var result = '';
    while (value > 0) {
      value--;
      result = String.fromCharCode(65 + value % 26) + result;
      value ~/= 26;
    }
    return result;
  }

  static String _xml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
