import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/constants.dart';

/// These are physical shortcut keys, not translated copy. Both modifier
/// families are accepted; the hint follows the current OS.
abstract final class YorksCalculatorShortcuts {
  static bool get isMac =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;
  static String get save => isMac ? '⌘S' : 'Ctrl+S';
  static String get undo => isMac ? '⌘Z' : 'Ctrl+Z';
  static String get redo => isMac ? '⇧⌘Z' : 'Ctrl+Shift+Z';
  static String get addRow => isMac ? '⇧⌘↵' : 'Ctrl+Shift+Enter';
  static String get duplicateRow => isMac ? '⌥⌘↵' : 'Ctrl+Alt+Enter';
  static String get print => isMac ? '⌘P' : 'Ctrl+P';
}

class YorksShortcutHint extends StatelessWidget {
  const YorksShortcutHint(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppTypography.labelSmall.copyWith(color: color ?? AppColors.muted),
  );
}

/// Code-native airflow mark: independent of a stale tree-shaken icon font.
class YorksDuctIcon extends StatelessWidget {
  const YorksDuctIcon({super.key, this.size = 22});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _AirflowPainter()),
  );
}

class _AirflowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = AppColors.inkSecondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(3, 8)
        ..lineTo(14, 8)
        ..cubicTo(20, 8, 20, 2, 16, 3)
        ..cubicTo(14, 3, 14, 4, 14, 5),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(3, 12)
        ..lineTo(18, 12)
        ..cubicTo(23, 12, 23, 18, 19, 18)
        ..lineTo(18, 18),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(3, 16)
        ..lineTo(11, 16)
        ..cubicTo(16, 16, 16, 22, 12, 21)
        ..lineTo(11, 21),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AirflowPainter oldDelegate) => false;
}

/// Consistent anchored dropdown, with native menu keyboard/focus behavior.
/// Filtering is for long project/person lists; finite engineering choices stay
/// select-only. Labels are supplied from the existing language catalogue.
class YorksCalculatorSelect<T> extends StatefulWidget {
  const YorksCalculatorSelect({
    super.key,
    required this.label,
    required this.entries,
    required this.onSelected,
    this.value,
    this.searchable = false,
    this.hint,
    this.onValidityChanged,
  });
  final String label;
  final String? hint;
  final T? value;
  final bool searchable;
  final List<DropdownMenuEntry<T>> entries;
  final ValueChanged<T?>? onSelected;
  final ValueChanged<bool>? onValidityChanged;
  @override
  State<YorksCalculatorSelect<T>> createState() => _CalculatorSelectState<T>();
}

class _CalculatorSelectState<T> extends State<YorksCalculatorSelect<T>> {
  late final TextEditingController controller;
  int validityGeneration = 0;
  String labelFor(YorksCalculatorSelect<T> select) =>
      select.entries.where((e) => e.value == select.value).firstOrNull?.label ??
      '';
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: labelFor(widget))
      ..addListener(reportValidity);
    reportValidity();
  }

  void reportValidity() {
    if (widget.onValidityChanged == null) return;
    final generation = ++validityGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == validityGeneration) {
        widget.onValidityChanged!(
          widget.value != null && controller.text == labelFor(widget),
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant YorksCalculatorSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value ||
        (controller.text == labelFor(oldWidget) &&
            labelFor(widget) != labelFor(oldWidget))) {
      controller.text = labelFor(widget);
    }
    reportValidity();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = LayoutBuilder(
      builder: (context, box) => DropdownMenu<T>(
        key: PageStorageKey(
          'calculator-select:${widget.label}:${widget.value}',
        ),
        controller: controller,
        width: box.maxWidth,
        initialSelection: widget.value,
        enabled: widget.onSelected != null,
        label: Text(widget.label),
        hintText: widget.hint,
        enableFilter: widget.searchable,
        enableSearch: widget.searchable,
        requestFocusOnTap: widget.searchable,
        menuHeight: 300,
        textStyle: AppTypography.bodyMedium.copyWith(color: AppColors.ink),
        inputDecorationTheme: InputDecorationTheme(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
          filled: true,
          fillColor: AppColors.surfaceContainerLowest,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: const BorderSide(color: AppColors.line),
          ),
        ),
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(
            AppColors.surfaceContainerLowest,
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(4),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(AppSpacing.xs)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              side: const BorderSide(color: AppColors.line),
            ),
          ),
        ),
        dropdownMenuEntries: widget.entries,
        onSelected: widget.onSelected,
      ),
    );
    return CalculatorQueryUndoScope(
      query: widget.searchable,
      child: widget.searchable
          ? field
          : MergeSemantics(
              child: Semantics(
                label: '${widget.label}: ${labelFor(widget)}',
                child: field,
              ),
            ),
    );
  }
}

/// Search inside a picker is text editing, not an edit to calculator inputs.
class CalculatorQueryUndoScope extends InheritedWidget {
  const CalculatorQueryUndoScope({
    super.key,
    required this.query,
    required super.child,
  });
  final bool query;
  @override
  bool updateShouldNotify(CalculatorQueryUndoScope oldWidget) =>
      query != oldWidget.query;
}

class YorksCalculatorHistoryAction<T extends Intent> extends Action<T> {
  YorksCalculatorHistoryAction(this.perform);
  final VoidCallback perform;
  bool get query =>
      FocusManager.instance.primaryFocus?.context
          ?.getInheritedWidgetOfExactType<CalculatorQueryUndoScope>()
          ?.query ==
      true;
  @override
  Object? invoke(T intent) {
    if (query) return callingAction?.invoke(intent);
    perform();
    return null;
  }
}

class YorksCalculatorManagedScope extends InheritedWidget {
  const YorksCalculatorManagedScope({super.key, required super.child});
  static bool isManaged(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<YorksCalculatorManagedScope>() !=
      null;
  @override
  bool updateShouldNotify(YorksCalculatorManagedScope oldWidget) => false;
}
