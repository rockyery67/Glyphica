import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_controller.dart';
import '../../core/theme.dart';
import '../../shared/widgets.dart';
import '../../shared/work_indicator.dart';
import 'engine.dart';
import 'models.dart';
import 'worker.dart';

class StyleScreen extends ConsumerStatefulWidget {
  const StyleScreen({super.key});
  @override
  ConsumerState<StyleScreen> createState() => _StyleScreenState();
}

class _StyleScreenState extends ConsumerState<StyleScreen> {
  late ArtSettings settings;
  late final TextEditingController custom;
  final runner = ConversionRunner();
  Timer? debounce;
  RenderBundle? preview;
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    settings = ref.read(appProvider).draftSettings;
    custom = TextEditingController(text: settings.customRamp);
    refresh();
  }

  void change(ArtSettings next) {
    runner.cancel();
    debounce?.cancel();
    setState(() {
      settings = next;
      busy = true;
      error = null;
    });
    debounce = Timer(const Duration(milliseconds: 350), refresh);
  }

  Future<void> refresh() async {
    final source = ref.read(appProvider).draft;
    if (source == null) return;
    try {
      final result = await runner.run<RenderBundle>(
        WorkRequest(source.path, settings, kind: WorkKind.preview),
      );
      if (!mounted || result == null) return;
      setState(() {
        preview = result;
        busy = false;
        error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    runner.cancel();
    custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(appProvider).draft;
    if (source == null) {
      return const StudioScaffold(
        child: EmptyState(
          title: 'Choose an image',
          message: 'Import an image from the studio first.',
        ),
      );
    }
    final w = settings.rotation.isOdd ? source.height : source.width;
    final h = settings.rotation.isOdd ? source.width : source.height;
    final rows = math.max(
      1,
      (h *
              (settings.cropBottom - settings.cropTop) /
              (w * (settings.cropRight - settings.cropLeft)) *
              settings.width *
              settings.cellAspect)
          .round(),
    );
    final rampError = settings.mode == ArtMode.custom
        ? ArtEngine.validateRamp(settings.customRamp)
        : null;
    return StudioScaffold(
      title: 'Style & tone',
      bottom: FilledButton.icon(
        key: const Key('generate-artwork'),
        onPressed: rampError != null
            ? null
            : () {
                debounce?.cancel();
                runner.cancel();
                ref.read(appProvider).draftSettings = settings;
                context.push('/generate');
              },
        icon: const Icon(Icons.auto_awesome, size: 18),
        label: const Text('Generate artwork'),
      ),
      child: ListView(
        children: [
          const SizedBox(height: 12),
          const Eyebrow('02 / Compose in characters', accent: true),
          const SizedBox(height: 12),
          Text(
            'Every shade, a glyph.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 18),
          Surface(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    children: [
                      const Eyebrow('Live study'),
                      const Spacer(),
                      Text(
                        busy ? 'UPDATING…' : '56 COL MAX',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                if (preview != null)
                  ArtCanvas(
                    text: preview!.output.text,
                    columns: preview!.output.columns,
                    rows: preview!.output.rows,
                    height: 250,
                  )
                else
                  SizedBox(
                    height: 250,
                    child: Center(
                      child: error != null
                          ? const Icon(Icons.error_outline)
                          : const Icon(Icons.grid_on_outlined, size: 40),
                    ),
                  ),
                const SizedBox(height: 8),
                if (busy) const WorkIndicator(),
                if (preview != null)
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      'Preview: ${preview!.output.characterCount} characters · ${preview!.output.rows} lines',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Tip(error!, warning: true),
            ),
          const SectionTitle('Choose a palette'),
          SizedBox(
            height: 135,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ArtMode.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final mode = ArtMode.values[i],
                    selected = settings.mode == ArtMode.values[i];
                final reduced =
                    ref.watch(appProvider).reduceMotion ||
                    MediaQuery.disableAnimationsOf(context);
                return InkWell(
                  onTap: () => change(settings.copyWith(mode: mode)),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: reduced ? 0 : 180),
                    width: 175,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                          : Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.secondary
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                mode.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (selected)
                              Icon(
                                Icons.check,
                                size: 16,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Text(
                            mode.description,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          mode.ramp,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                            fontFamily: mono,
                            fontFamilyFallback: ['GlyphicaDots'],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (settings.mode == ArtMode.custom)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextField(
                controller: custom,
                decoration: InputDecoration(
                  labelText: 'Light → dense ramp',
                  helperText:
                      'Spaces are meaningful. Glyph order is preserved.',
                  errorText: rampError,
                  errorMaxLines: 3,
                ),
                style: const TextStyle(
                  fontFamily: mono,
                  fontFamilyFallback: ['GlyphicaDots'],
                ),
                onChanged: (s) => change(settings.copyWith(customRamp: s)),
              ),
            ),
          const SectionTitle('A matter of detail'),
          Surface(
            child: Column(
              children: [
                Wrap(
                  spacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('Compact · 40'),
                      onPressed: () => change(settings.copyWith(width: 40)),
                    ),
                    ActionChip(
                      key: const Key('high-detail'),
                      label: const Text('High detail · 100'),
                      onPressed: () => change(
                        settings
                            .withLook(QualityLook.detail)
                            .copyWith(width: 100),
                      ),
                    ),
                    ActionChip(
                      label: const Text('Fine · 160'),
                      onPressed: () => change(settings.copyWith(width: 160)),
                    ),
                  ],
                ),
                SettingSlider(
                  label: 'Output width',
                  value: settings.width.toDouble(),
                  min: 16,
                  max: 240,
                  divisions: 224,
                  display: '${settings.width} cols',
                  onChanged: (v) => change(settings.copyWith(width: v.round())),
                ),
                Text(
                  'Final output: ${settings.width} × $rows cells · ${settings.width * rows + rows - 1} characters incl. line breaks',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'More detail means a longer message. Fine features remain limited by the image and text resolution.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SectionTitle('Compare the feeling'),
          if (preview?.comparisons.length == 3)
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final output = preview!.comparisons[i];
                  return SizedBox(
                    width: 168,
                    child: InkWell(
                      onTap: () =>
                          change(settings.withLook(QualityLook.values[i])),
                      child: Surface(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            ArtCanvas(
                              text: output.text,
                              columns: output.columns,
                              rows: output.rows,
                              height: 132,
                              interactive: false,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              [
                                'Clear silhouette',
                                'Smooth shading',
                                'Dense detail',
                              ][i],
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          else
            const Text('Comparison studies appear after the preview is ready.'),
          const SectionTitle('Tonal controls'),
          Surface(
            child: Column(
              children: [
                SettingSlider(
                  label: 'Brightness',
                  value: settings.brightness,
                  min: -.4,
                  max: .4,
                  display: '${(settings.brightness * 100).round()}%',
                  onChanged: (v) => change(settings.copyWith(brightness: v)),
                ),
                SettingSlider(
                  label: 'Contrast',
                  value: settings.contrast,
                  min: .5,
                  max: 2.5,
                  display: '${(settings.contrast * 100).round()}%',
                  onChanged: (v) => change(settings.copyWith(contrast: v)),
                ),
                SettingSlider(
                  label: 'Gamma',
                  value: settings.gamma,
                  min: .4,
                  max: 2.2,
                  display: settings.gamma.toStringAsFixed(2),
                  onChanged: (v) => change(settings.copyWith(gamma: v)),
                ),
                SettingSlider(
                  label: 'Edge enhancement',
                  value: settings.edge,
                  min: 0,
                  max: .6,
                  display: '${(settings.edge * 100).round()}%',
                  onChanged: (v) => change(settings.copyWith(edge: v)),
                ),
                SettingSlider(
                  label: 'Character cell aspect',
                  value: settings.cellAspect,
                  min: .35,
                  max: .8,
                  display: settings.cellAspect.toStringAsFixed(2),
                  onChanged: (v) => change(settings.copyWith(cellAspect: v)),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Invert light & dark'),
                  subtitle: const Text('Changes the generated text.'),
                  value: settings.invert,
                  onChanged: (v) => change(settings.copyWith(invert: v)),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Floyd–Steinberg dithering'),
                  subtitle: const Text(
                    'Smoother tones; may add texture or noise.',
                  ),
                  value: settings.dither,
                  onChanged: (v) => change(settings.copyWith(dither: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              custom.text = ' .:-=+*#%@';
              change(
                ArtSettings(
                  rotation: settings.rotation,
                  cropLeft: settings.cropLeft,
                  cropTop: settings.cropTop,
                  cropRight: settings.cropRight,
                  cropBottom: settings.cropBottom,
                  matte: settings.matte,
                ),
              );
            },
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset style & tone'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
