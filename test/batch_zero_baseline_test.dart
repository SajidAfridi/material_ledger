import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:material_ledger/shared/models/backend_configuration.dart';
import 'package:material_ledger/shared/models/material_item.dart';
import 'package:material_ledger/shared/models/nexus_feature_flags.dart';
import 'package:material_ledger/shared/sync/supabase_bootstrap.dart';

void main() {
  group('Backend startup policy', () {
    test('release rejects absent or partial configuration', () {
      final absent = BackendConfiguration.resolve(
        supabaseUrl: '',
        supabaseAnonKey: '',
        isRelease: true,
        allowLocalDevelopment: true,
        localDemoPassword: 'local-only',
      );
      final partial = BackendConfiguration.resolve(
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: '',
        isRelease: true,
        allowLocalDevelopment: false,
        localDemoPassword: '',
      );

      expect(absent.mode, BackendStartupMode.blocked);
      expect(partial.mode, BackendStartupMode.blocked);
    });

    test('release requires HTTPS and accepts complete HTTPS configuration', () {
      final insecure = BackendConfiguration.resolve(
        supabaseUrl: 'http://example.supabase.co',
        supabaseAnonKey: 'publishable-key',
        isRelease: true,
        allowLocalDevelopment: false,
        localDemoPassword: '',
      );
      final valid = BackendConfiguration.resolve(
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'publishable-key',
        isRelease: true,
        allowLocalDevelopment: false,
        localDemoPassword: '',
      );

      expect(insecure.mode, BackendStartupMode.blocked);
      expect(valid.mode, BackendStartupMode.supabase);
      expect(valid.usesSupabase, true);
    });

    test('client startup rejects service-role and secret keys', () {
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'role': 'service_role'})),
      );
      final serviceJwt = 'header.$payload.signature';
      for (final key in [serviceJwt, 'sb_secret_not-a-client-key']) {
        final config = BackendConfiguration.resolve(
          supabaseUrl: 'https://example.supabase.co',
          supabaseAnonKey: key,
          isRelease: true,
          allowLocalDevelopment: false,
          localDemoPassword: '',
        );
        expect(config.mode, BackendStartupMode.blocked);
      }
    });

    test('local mode is explicit and unavailable to release builds', () {
      final implicit = BackendConfiguration.resolve(
        supabaseUrl: '',
        supabaseAnonKey: '',
        isRelease: false,
        allowLocalDevelopment: false,
        localDemoPassword: '',
      );
      final explicit = BackendConfiguration.resolve(
        supabaseUrl: '',
        supabaseAnonKey: '',
        isRelease: false,
        allowLocalDevelopment: true,
        localDemoPassword: 'local-only',
      );

      expect(implicit.mode, BackendStartupMode.blocked);
      expect(explicit.mode, BackendStartupMode.localDevelopment);
    });

    test('explicit local mode also requires an explicit local password', () {
      final missingPassword = BackendConfiguration.resolve(
        supabaseUrl: '',
        supabaseAnonKey: '',
        isRelease: false,
        allowLocalDevelopment: true,
        localDemoPassword: '',
      );

      expect(missingPassword.mode, BackendStartupMode.blocked);
    });
  });

  group('Nexus feature flags', () {
    test('all transformed modules default off', () {
      const flags = NexusFeatureFlags();

      expect(flags.projects, false);
      expect(flags.browseMaterials, false);
      expect(flags.phase1Planning, false);
      expect(flags.procurementReview, false);
      expect(flags.phase2Requests, false);
    });

    test('a batch can be enabled without exposing later batches', () {
      const defaults = NexusFeatureFlags();
      final batchOne = defaults.copyWith(projects: true);

      expect(batchOne.projects, true);
      expect(batchOne.browseMaterials, false);
      expect(batchOne.phase1Planning, false);
      expect(batchOne.procurementReview, false);
      expect(batchOne.phase2Requests, false);
    });
  });

  group('Commercial payload boundaries', () {
    final material = MaterialItem(
      id: 'mat-1',
      name: 'Copper Pipe',
      urduName: '',
      category: MaterialCategory.pipes,
      unit: MaterialUnit.meters,
      quantity: 120,
      unitPrice: 42.5,
      reservedQty: 15,
    );

    test('shared material payload excludes cost and local reservations', () {
      final payload = material.toSharedJson();

      expect(payload['quantity'], 120);
      expect(payload.containsKey('unitPrice'), false);
      expect(payload.containsKey('reservedQty'), false);
      expect(MaterialItem.fromJson(payload).unitPrice, 0);
    });

    test('cloud seeding strips every protected legacy field', () {
      final employee = SupabaseBootstrap.sanitizeForCloud('employees', {
        'id': 'emp-1',
        'fullName': 'Employee',
        'salaryAED': 7000,
        'basicWageAED': 3000,
      });
      final project = SupabaseBootstrap.sanitizeForCloud('projects', {
        'id': 'project-1',
        'name': 'Project',
        'contractValueAED': 500000,
      });
      final catalog = SupabaseBootstrap.sanitizeForCloud(
        'materials',
        material.toJson(),
      );

      expect(employee.containsKey('salaryAED'), false);
      expect(employee.containsKey('basicWageAED'), false);
      expect(project.containsKey('contractValueAED'), false);
      expect(catalog.containsKey('unitPrice'), false);
      expect(catalog.containsKey('reservedQty'), false);
      expect(catalog['name'], 'Copper Pipe');
    });
  });
}
