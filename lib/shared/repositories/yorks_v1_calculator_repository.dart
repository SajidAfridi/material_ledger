import '../models/yorks_v1_calculator_workspace.dart';
import 'yorks_v1_project_repository.dart';

class YorksCalculatorRepository {
  const YorksCalculatorRepository(this.rpc);
  final YorksV1ProjectRpcClient? rpc;
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> params = const {},
  ]) {
    final client = rpc;
    if (client == null) throw StateError('CALCULATOR_CONNECTION_REQUIRED');
    return client.invoke(functionName: name, parameters: params);
  }

  Future<Map<String, dynamic>> list({
    String search = '',
    int offset = 0,
    bool archived = false,
    String kind = 'all',
    String scope = 'all',
  }) => call('v1_list_calculators', {
    'p_search': search,
    'p_offset': offset,
    'p_archived': archived,
    'p_kind': kind,
    'p_scope': scope,
  });
  Future<YorksCalculatorRecord> get(String id) async {
    final record = YorksCalculatorRecord(
      await call('v1_get_calculator', {'p_id': id}),
    );
    YorksCalculatorFiles.validate(record.payload, expectedKind: record.kind);
    return record;
  }

  Future<Map<String, dynamic>> options() => call('v1_calculator_options');
  Future<YorksCalculatorRecord> save(
    Map<String, dynamic> payload,
    String key,
  ) async {
    YorksCalculatorFiles.validate(
      Map<String, dynamic>.from(payload['payload'] as Map),
      expectedKind: payload['kind'] as String,
    );
    return YorksCalculatorRecord(
      await call('v1_save_calculator', {
        'p_payload': payload,
        'p_idempotency_key': key,
      }),
    );
  }

  Future<YorksCalculatorRecord> manage(
    Map<String, dynamic> payload,
    String key,
  ) async => YorksCalculatorRecord(
    await call('v1_manage_calculator', {
      'p_payload': payload,
      'p_idempotency_key': key,
    }),
  );
}
