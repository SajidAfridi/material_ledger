import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/controllers/yorks_v1_calculator_edit_history.dart';

void main() {
  Map<String, dynamic> value(String flow, {String width = '500'}) => {
    'title': 'AHU',
    'payload': {
      'flow': flow,
      'width': width,
      'future': {'retained': true},
    },
  };
  test(
    'typing coalesces by field while independent changes undo separately',
    () {
      final history = YorksCalculatorEditHistory();
      final now = DateTime.utc(2026, 10, 6);
      history.reset(value(''));
      history.record(value('1'), now: now);
      history.record(
        value('10'),
        now: now.add(const Duration(milliseconds: 100)),
      );
      history.record(
        value('100'),
        now: now.add(const Duration(milliseconds: 200)),
      );
      history.record(
        value('100', width: '600'),
        now: now.add(const Duration(milliseconds: 300)),
      );
      expect(history.undo()!['payload']['width'], '500');
      expect(history.undo()!['payload']['flow'], '');
      expect(history.redo()!['payload']['flow'], '100');
      expect(history.redo()!['payload']['future'], {'retained': true});
    },
  );
  test(
    'new edits replace redo without changing previous immutable snapshots',
    () {
      final history = YorksCalculatorEditHistory();
      final first = value('100');
      history.reset(first);
      first['payload']['future']['retained'] = false;
      history.record(value('200'), atomic: true);
      expect(history.undo()!['payload']['future'], {'retained': true});
      history.record(value('300'), atomic: true);
      expect(history.canRedo, isFalse);
      expect(history.undo()!['payload']['flow'], '100');
    },
  );
  test('history stays bounded for repeated large edits', () {
    final history = YorksCalculatorEditHistory(
      maximumEntries: 8,
      maximumBytes: 1600,
    );
    history.reset(value('0'));
    for (var i = 1; i < 500; i++) {
      history.record(value('$i'), atomic: true);
    }
    expect(history.depth, lessThanOrEqualTo(8));
    expect(history.bytes, lessThanOrEqualTo(1600));
    expect(history.undo()!['payload']['flow'], '498');
  });
  test('saved timestamps do not create edits or prevent exact redo', () {
    final history = YorksCalculatorEditHistory();
    history.reset({...value('100'), 'savedAt': 'old'});
    history.record({...value('100'), 'savedAt': 'new'});
    expect(history.canUndo, isFalse);
  });
}
