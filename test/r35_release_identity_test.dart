import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dirty in [false, true]) {
    test('R35 injects actual checkout identity, dirty=$dirty', () async {
      final temp = Directory.systemTemp.createTempSync('yorks-release-test-');
      addTearDown(() => temp.deleteSync(recursive: true));
      final repo = Directory('${temp.path}/repo')..createSync();
      final tool = Directory('${repo.path}/tool')..createSync();
      final script = File('${tool.path}/r35.sh');
      script.writeAsStringSync(File('tool/r35.sh').readAsStringSync());
      final bin = Directory('${temp.path}/bin')..createSync();
      final flutter = File('${bin.path}/flutter');
      flutter.writeAsStringSync('#!/bin/sh\nprintf "%s\\n" "\$@"\n');
      expect(Process.runSync('chmod', ['+x', flutter.path]).exitCode, 0);

      Future<ProcessResult> git(List<String> args) =>
          Process.run('git', args, workingDirectory: repo.path);
      expect((await git(['init', '-q'])).exitCode, 0);
      expect((await git(['add', '.'])).exitCode, 0);
      expect(
        (await git([
          '-c',
          'user.name=Yorks fixture',
          '-c',
          'user.email=fixture@example.invalid',
          'commit',
          '-qm',
          'Synthetic source',
        ])).exitCode,
        0,
      );
      final sha = (await git(['rev-parse', 'HEAD'])).stdout.toString().trim();
      if (dirty)
        File('${repo.path}/untracked.dart').writeAsStringSync('// edit');
      final result = await Process.run(
        'bash',
        [script.path, 'run'],
        workingDirectory: repo.path,
        environment: {
          ...Platform.environment,
          'PATH': '${bin.path}:${Platform.environment['PATH']}',
          'R35_CONFIG_FILE': '${temp.path}/absent.env',
          'R35_ENVIRONMENT': 'ci',
          'SUPABASE_URL': 'https://ci.invalid',
          'SUPABASE_ANON_KEY': 'ci-publishable-key',
          'YORKS_RELEASE_ID': 'operator-label-must-not-win',
        },
      );
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(
        result.stdout.toString().split('\n'),
        contains('--dart-define=YORKS_RELEASE_ID=$sha${dirty ? '-dirty' : ''}'),
      );
      expect(result.stdout, isNot(contains('operator-label-must-not-win')));
    }, skip: Platform.isWindows);
  }
}
