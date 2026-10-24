import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_controller.dart';
import '../core/output_service.dart';
import '../core/theme.dart';
import '../features/conversion/models.dart';

void notice(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> safely(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) notice(context, e.toString());
  }
}

Future<void> copyArtwork(BuildContext context, String text) async {
  await safely(context, () async {
    await OutputService().copy(text);
    if (context.mounted) {
      notice(context, 'Copied · spaces and line breaks preserved');
    }
  });
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 34});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: ink,
      borderRadius: BorderRadius.circular(size * .28),
    ),
    alignment: Alignment.center,
    child: Text(
      '@⁙',
      style: TextStyle(
        fontFamily: mono,
        color: Colors.white,
        fontSize: size * .4,
        letterSpacing: -2,
      ),
    ),
  );
}

class StudioScaffold extends StatelessWidget {
  const StudioScaffold({
    super.key,
    required this.child,
    this.title,
    this.tab,
    this.actions = const [],
    this.bottom,
    this.padding = true,
  });
  final Widget child;
  final String? title;
  final int? tab;
  final List<Widget> actions;
  final Widget? bottom;
  final bool padding;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: title == null
          ? const Row(
              children: [
                BrandMark(),
                SizedBox(width: 10),
                Text(
                  'GLYPHICA',
                  style: TextStyle(
                    fontSize: 21,
                    letterSpacing: -.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : Text(
              title!,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
            ),
      actions: [
        ...actions,
        if (title == null)
          const Padding(
            padding: EdgeInsets.only(right: 20),
            child: Icon(Icons.shield_outlined, size: 21),
          ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: padding
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: child,
                )
              : child,
        ),
      ),
    ),
    bottomNavigationBar: tab != null
        ? NavigationBar(
            selectedIndex: tab!,
            onDestinationSelected: (i) =>
                context.go(['/', '/history', '/settings'][i]),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome),
                label: 'Create',
              ),
              NavigationDestination(
                icon: Icon(Icons.bookmarks_outlined),
                selectedIcon: Icon(Icons.bookmarks),
                label: 'Saved',
              ),
              NavigationDestination(icon: Icon(Icons.tune), label: 'Settings'),
            ],
          )
        : bottom == null
        ? null
        : SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 856),
                  child: bottom,
                ),
              ),
            ),
          ),
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.accent = false});
  final String text;
  final bool accent;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: accent ? Theme.of(context).colorScheme.secondary : null,
    ),
  );
}

class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?trailing,
      ],
    ),
  );
}

class Tip extends StatelessWidget {
  const Tip(this.text, {super.key, this.warning = false});
  final String text;
  final bool warning;
  @override
  Widget build(BuildContext context) => Surface(
    padding: const EdgeInsets.all(14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          warning ? Icons.info_outline : Icons.lightbulb_outline,
          size: 19,
          color: Theme.of(context).colorScheme.secondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.icon = Icons.grid_on_outlined,
  });
  final String title, message;
  final Widget? action;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 36, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        if (action != null)
          Padding(padding: const EdgeInsets.only(top: 20), child: action),
      ],
    ),
  );
}

class SourceThumbnail extends StatelessWidget {
  const SourceThumbnail(this.source, {super.key, this.size = 64});
  final SourceImage source;
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.file(
      File(source.thumbnailPath),
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth: (size * 2).round(),
      errorBuilder: (_, _, _) => SizedBox(
        width: size,
        height: size,
        child: const Icon(Icons.image_not_supported_outlined),
      ),
    ),
  );
}

/// Fit/zoom is only a rendering transform. No soft wrapping or text mutation.
class ArtCanvas extends StatefulWidget {
  const ArtCanvas({
    super.key,
    required this.text,
    required this.columns,
    required this.rows,
    this.height = 300,
    this.interactive = true,
    this.dark = false,
  });
  final String text;
  final int columns, rows;
  final double height;
  final bool interactive, dark;
  @override
  State<ArtCanvas> createState() => _ArtCanvasState();
}

class _ArtCanvasState extends State<ArtCanvas> {
  final transform = TransformationController();
  @override
  void didUpdateWidget(covariant ArtCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) transform.value = Matrix4.identity();
  }

  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Container(
      height: widget.height,
      color: widget.dark ? const Color(0xFF161A19) : const Color(0xFFFFFEFC),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = math
              .min(
                (constraints.maxWidth - 28) / math.max(1, widget.columns) / .6,
                (widget.height - 28) / math.max(1, widget.rows) / 1.2,
              )
              .clamp(0.3, 22.0);
          final art = Center(
            child: Text(
              widget.text,
              softWrap: false,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: mono,
                fontFamilyFallback: const ['GlyphicaDots'],
                fontSize: size,
                height: 1.2,
                letterSpacing: 0,
                fontFeatures: const [FontFeature.disable('liga')],
                color: widget.dark ? const Color(0xFFE9ECE5) : ink,
              ),
            ),
          );
          if (!widget.interactive) return art;
          return Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: transform,
                  minScale: .5,
                  maxScale: 14,
                  boundaryMargin: const EdgeInsets.all(400),
                  child: art,
                ),
              ),
              Positioned(
                bottom: 6,
                right: 6,
                child: IconButton.filledTonal(
                  tooltip: 'Reset zoom',
                  iconSize: 17,
                  onPressed: () => transform.value = Matrix4.identity(),
                  icon: const Icon(Icons.fit_screen),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class SettingSlider extends StatelessWidget {
  const SettingSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.display,
    this.divisions,
  });
  final String label, display;
  final double value, min, max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              display,
              style: const TextStyle(fontFamily: mono, fontSize: 11),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          label: display,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class MotionEntry extends ConsumerWidget {
  const MotionEntry({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduced =
        ref.watch(appProvider).reduceMotion ||
        MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduced ? 1 : 0, end: 1),
      duration: Duration(milliseconds: reduced ? 0 : 350),
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 10),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
