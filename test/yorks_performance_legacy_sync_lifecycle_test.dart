import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/sync/realtime_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Client client;
  late SharedPreferences preferences;
  late ProviderContainer container;
  late RealtimeSync sync;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'projects_list_v1': '[{"id":"project-1"}]',
    });
    preferences = await SharedPreferences.getInstance();
    client = _Client();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    final provider = Provider((ref) => RealtimeSync(client, ref));
    sync = container.read(provider);
  });

  tearDown(() async {
    await sync.stop();
    await client.auth.events.close();
    container.dispose();
  });

  test(
    'logout during token setup cannot attach a late auth listener',
    () async {
      client.realtime.pendingAuth = Completer<void>();
      final started = sync.start();
      await sync.stop();
      client.realtime.pendingAuth!.complete();
      await started;
      expect(client.auth.events.hasListener, isFalse);
      expect(client.channels, isEmpty);
    },
  );

  test(
    'repeated starts retain exactly one owner for each legacy table',
    () async {
      await Future.wait([sync.start(), sync.start()]);
      expect(client.channels, hasLength(14));
      expect(
        client.channels.map((channel) => channel.table).toSet(),
        hasLength(14),
      );
      expect(client.auth.listenCount, 1);
      await sync.stop();
      expect(client.removed, hasLength(14));
      expect(client.auth.events.hasListener, isFalse);
    },
  );

  test('a stopped instance cannot restart or reattach auth', () async {
    await sync.stop();
    await sync.start();
    expect(client.realtime.authCalls, 0);
    expect(client.auth.events.hasListener, isFalse);
    expect(client.channels, isEmpty);
  });

  test('an already queued callback cannot change a logged-out cache', () async {
    await sync.start();
    final projects = client.channels.singleWhere((c) => c.table == 'projects');
    await sync.stop();
    projects.callback!(
      PostgresChangePayload(
        schema: 'public',
        table: 'projects',
        commitTimestamp: DateTime(2026),
        eventType: PostgresChangeEvent.delete,
        newRecord: const {},
        oldRecord: const {'id': 'project-1'},
        errors: null,
      ),
    );
    expect(preferences.getString('projects_list_v1'), '[{"id":"project-1"}]');
  });
}

class _Auth extends Fake implements GoTrueClient {
  int listenCount = 0;
  late final events = StreamController<AuthState>.broadcast(
    onListen: () => listenCount += 1,
  );
  @override
  Stream<AuthState> get onAuthStateChange => events.stream;
  @override
  Session get currentSession => Session(
    accessToken: 'test-only-not-a-real-token',
    tokenType: 'bearer',
    user: const User(
      id: 'test-user',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-09-03T00:00:00Z',
    ),
  );
}

class _Realtime extends Fake implements RealtimeClient {
  Completer<void>? pendingAuth;
  int authCalls = 0;
  @override
  Future<void> setAuth(String? token) async {
    authCalls += 1;
    await pendingAuth?.future;
  }
}

class _Client extends Fake implements SupabaseClient {
  @override
  final _Auth auth = _Auth();
  @override
  final _Realtime realtime = _Realtime();
  final channels = <_Channel>[];
  final removed = <RealtimeChannel>[];

  @override
  RealtimeChannel channel(
    String name, {
    RealtimeChannelConfig opts = const RealtimeChannelConfig(),
  }) {
    final channel = _Channel();
    channels.add(channel);
    return channel;
  }

  @override
  Future<String> removeChannel(RealtimeChannel channel) async {
    removed.add(channel);
    return 'ok';
  }
}

class _Channel extends Fake implements RealtimeChannel {
  String? table;
  void Function(PostgresChangePayload)? callback;

  @override
  RealtimeChannel onPostgresChanges({
    required PostgresChangeEvent event,
    String? schema,
    String? table,
    PostgresChangeFilter? filter,
    required void Function(PostgresChangePayload) callback,
  }) {
    this.table = table;
    this.callback = callback;
    return this;
  }

  @override
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus, Object?)? callback,
    Duration? timeout,
  ]) => this;
}
