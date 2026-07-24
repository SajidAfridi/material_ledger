import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/controllers/material_line_grid_controller.dart';
import '../../../../shared/models/material_line_draft.dart';
import '../../../../shared/providers/material_master_provider.dart';
import '../../../../shared/providers/permissions_provider.dart';
import '../../../../shared/services/catalogue_csv_download.dart';
import '../../../../shared/services/material_line_csv_export.dart';
import '../../../../shared/widgets/material_line_grid.dart';

class MaterialLineGridDemoScreen extends ConsumerStatefulWidget {
  const MaterialLineGridDemoScreen({super.key});

  @override
  ConsumerState<MaterialLineGridDemoScreen> createState() =>
      _MaterialLineGridDemoScreenState();
}

class _MaterialLineGridDemoScreenState
    extends ConsumerState<MaterialLineGridDemoScreen> {
  late final MaterialLineGridController _controller;
  late final Duration _seedDuration;
  DateTime? _lastAutosave;
  bool _mobilePreview = false;

  @override
  void initState() {
    super.initState();
    final stopwatch = Stopwatch()..start();
    final allowed = ref.read(canViewCommercialsProvider);
    final lines = List.generate(500, _demoLine);
    final commercials = allowed
        ? {
            for (final line in lines)
              line.id: MaterialLineCommercial(
                lineId: line.id,
                unitCostAED: 18 + (int.parse(line.id.split('-').last) % 17),
              ),
          }
        : const <String, MaterialLineCommercial>{};
    _controller = MaterialLineGridController(
      lines: lines,
      commercials: commercials,
      commercialsEnabled: allowed,
      onAutosave: (_, _) {
        if (mounted) setState(() => _lastAutosave = DateTime.now());
      },
    );
    stopwatch.stop();
    _seedDuration = stopwatch.elapsed;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(child: Text('This diagnostic screen is unavailable.')),
      );
    }
    final units = ref
        .watch(selectableMaterialUnitsProvider)
        .map((unit) => unit.symbol)
        .toList();
    return Scaffold(
      body: NexusPageShell(
        eyebrow: 'Batch 7 diagnostic',
        title: 'Material line grid',
        description:
            'Isolated 500-row implementation spike. It is not connected to '
            'Phase 1 or any production workflow.',
        actions: [
          OutlinedButton.icon(
            key: const ValueKey('grid-preview-toggle'),
            onPressed: () => setState(() => _mobilePreview = !_mobilePreview),
            icon: Icon(
              _mobilePreview
                  ? Icons.desktop_windows_outlined
                  : Icons.phone_iphone_outlined,
              size: 17,
            ),
            label: Text(_mobilePreview ? 'Desktop preview' : 'Mobile preview'),
          ),
        ],
        inspector: _buildInspector(),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: _mobilePreview ? 390 : null,
            child: MaterialLineGrid(
              controller: _controller,
              units: units.isEmpty
                  ? const ['Nos', 'm', 'cm', 'Set', 'Pairs', 'Roll', 'Box']
                  : units,
              onExport: _export,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInspector() {
    return Column(
      children: [
        NexusSectionCard(
          title: 'Spike evidence',
          description: 'Performance and security boundaries.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Fact(
                label: 'Dataset',
                value: '${_controller.lines.length} virtualised rows',
              ),
              _Fact(
                label: 'Seed construction',
                value: '${_seedDuration.inMicroseconds} μs',
              ),
              _Fact(
                label: 'Commercial payload',
                value: _controller.commercialsEnabled
                    ? 'Authorised and separate'
                    : 'Not received',
              ),
              _Fact(
                label: 'Autosave',
                value: _lastAutosave == null
                    ? 'Waiting for a change'
                    : 'Captured in this session',
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        NexusSectionCard(
          title: 'Approved behaviour',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatusChip(
                label: 'Exact column contract',
                tone: NexusStatusTone.success,
                showDot: true,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Tab moves across cells. Enter moves down the same column. '
                'Paste accepts Excel tab-separated rows. Similar Row carries '
                'description, size, make/origin, unit and remarks only.',
                style: AppTypography.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _export() async {
    final csv = MaterialLineCsvExport.build(
      lines: _controller.lines,
      commercials: _controller.commercials,
      includeCommercials: _controller.commercialsEnabled,
    );
    final downloaded = await downloadCatalogueCsv(
      csv,
      filename: 'yorks-material-line-grid.csv',
    );
    if (!downloaded) {
      await Clipboard.setData(ClipboardData(text: csv));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          downloaded
              ? 'Material lines exported.'
              : 'CSV copied to the clipboard.',
        ),
      ),
    );
  }

  static MaterialLineDraft _demoLine(int index) {
    final number = index + 1;
    const descriptions = [
      'Supply Air Grille',
      'Volume Control Damper',
      'Copper Pipe Type L',
      'Phenolic Duct Insulation',
      'Condensate Drain Fitting',
    ];
    return MaterialLineDraft(
      id: 'demo-$number',
      description: descriptions[index % descriptions.length],
      size: index.isEven ? '500 x 500 mm' : 'Ø315 mm',
      modelSerial: index % 4 == 0
          ? 'YRK-${number.toString().padLeft(3, '0')}'
          : '',
      makeOrigin: index.isEven ? 'Yorks / UAE' : 'Approved equivalent',
      quantity: (index % 12) + 1,
      unitSymbol: index % 3 == 0 ? 'm' : 'Nos',
      remarks: index % 5 == 0 ? 'Coordinate with approved shop drawing' : '',
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: AppTypography.bodySmall)),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTypography.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}
