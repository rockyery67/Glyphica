import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_controller.dart';
import '../../shared/widgets.dart';
import '../../shared/work_indicator.dart';
import '../conversion/models.dart';
import '../conversion/worker.dart';
import '../export/export_sheet.dart';
import '../history/creation.dart';
import 'formatting.dart';

class DestinationScreen extends ConsumerStatefulWidget {
  const DestinationScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<DestinationScreen> createState() => _DestinationScreenState();
}

class _DestinationScreenState extends ConsumerState<DestinationScreen> {
  final runner = ConversionRunner();
  Timer? debounce;
  late DestinationProfile profile;
  late ArtSettings settings;
  late ArtSettings renderedSettings;
  late ArtOutput output;
  late TextEditingController budgetField;
  int budget = 12000, partIndex = 0;
  bool wrapper = false, labels = false, busy = false, available = true;
  String? error;
  @override
  void initState() {
    super.initState();
    final app = ref.read(appProvider),
        c = ref.read(appProvider).find(widget.id)!;
    profile = app.profiles.first;
    settings = c.settings;
    renderedSettings = c.settings;
    output = c.output;
    budget = profile.budget;
    budgetField = TextEditingController(text: '$budget');
    File(c.source.path).exists().then((v) {
      if (mounted) {
        setState(() => available = v);
        selectProfile(profile);
      }
    });
  }

  void selectProfile(DestinationProfile next) {
    runner.cancel();
    debounce?.cancel();
    final c = ref.read(appProvider).find(widget.id)!;
    SavedVariant? saved;
    for (final v in c.variants.reversed) {
      if (v.destination == next.id) {
        saved = v;
        break;
      }
    }
    setState(() {
      profile = next;
      budget = saved?.budget ?? next.budget;
      wrapper = saved?.codeBlock ?? next.codeBlock;
      labels = saved?.labels ?? false;
      budgetField.text = '$budget';
      partIndex = 0;
      error = null;
      busy = false;
      settings =
          saved?.settings ??
          c.settings.copyWith(
            width: math.min(c.output.columns, next.width),
            mode: next.preferredMode,
          );
      if (saved != null) {
        output = ArtOutput(
          text: saved.text,
          columns: settings.width,
          rows: saved.text.split('\n').length,
          sourceWidth: c.output.sourceWidth,
          sourceHeight: c.output.sourceHeight,
        );
      } else {
        output = c.output;
        if (!available) settings = c.settings;
      }
      renderedSettings = saved?.settings ?? c.settings;
    });
    if (saved == null && available) render();
  }

  void changeSettings(ArtSettings next) {
    runner.cancel();
    debounce?.cancel();
    setState(() {
      settings = next;
      busy = true;
      error = null;
    });
    debounce = Timer(const Duration(milliseconds: 350), render);
  }

  Future<void> render({bool fit = false}) async {
    if (!available) return;
    final c = ref.read(appProvider).find(widget.id)!;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await runner.run<RenderBundle>(
        WorkRequest(
          c.source.path,
          settings,
          kind: fit ? WorkKind.fit : WorkKind.finalRender,
          budget: budget,
          codeBlock: wrapper,
        ),
      );
      if (mounted && result != null) {
        setState(() {
          output = result.output;
          settings = result.settings;
          renderedSettings = result.settings;
          busy = false;
          partIndex = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          settings = renderedSettings;
          busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    runner.cancel();
    budgetField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider),
        c = ref.watch(appProvider).find(widget.id);
    if (c == null) {
      return const StudioScaffold(
        title: 'Destination',
        child: EmptyState(
          title: 'Artwork unavailable',
          message: 'Return to the saved collection.',
        ),
      );
    }
    List<MessagePart> parts = [];
    String? splitError;
    try {
      parts = MessageFormatter.split(
        output.text,
        budget: budget,
        codeBlock: wrapper,
        labels: labels,
      );
    } on FormatException catch (e) {
      splitError = e.message;
    }
    final whole = MessageFormatter.wrap(output.text, codeBlock: wrapper);
    final overBudget = whole.length > budget;
    final part = parts.isEmpty
        ? null
        : parts[partIndex.clamp(0, parts.length - 1)];
    final previewText = part?.raw ?? output.text;
    return StudioScaffold(
      title: 'Destination studio',
      child: ListView(
        children: [
          const SizedBox(height: 12),
          const Eyebrow('A version for every conversation', accent: true),
          const SizedBox(height: 12),
          Text(
            'Where will you paste this?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            key: ValueKey(profile.id),
            initialValue: profile.id,
            decoration: const InputDecoration(labelText: 'Destination'),
            items: app.profiles
                .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                .toList(),
            onChanged: (id) =>
                selectProfile(app.profiles.firstWhere((p) => p.id == id)),
          ),
          const SizedBox(height: 12),
          Tip(
            '${profile.guidance}\nWidth and budget are adjustable compatibility estimates.',
          ),
          if (!available)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Tip(
                'The source image is unavailable. Original text and saved variants can still be split, copied, and exported. Re-rendering requires the source.',
                warning: true,
              ),
            ),
          const SectionTitle('Make room for detail'),
          Surface(
            child: Column(
              children: [
                SettingSlider(
                  label: 'Variant width',
                  value: settings.width.toDouble(),
                  min: 8,
                  max: 240,
                  divisions: 232,
                  display: '${settings.width} cols',
                  onChanged: (v) {
                    if (available) {
                      changeSettings(settings.copyWith(width: v.round()));
                    }
                  },
                ),
                DropdownButtonFormField<ArtMode>(
                  key: ValueKey('${profile.id}-${settings.mode.name}'),
                  initialValue: settings.mode,
                  decoration: const InputDecoration(
                    labelText: 'Variant palette',
                  ),
                  items: ArtMode.values
                      .where(
                        (m) =>
                            m != ArtMode.custom ||
                            c.settings.mode == ArtMode.custom,
                      )
                      .map(
                        (m) => DropdownMenuItem(value: m, child: Text(m.label)),
                      )
                      .toList(),
                  onChanged: available
                      ? (m) => changeSettings(settings.copyWith(mode: m))
                      : null,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: budgetField,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Message budget (UTF-16 units)',
                    helperText: 'Estimate, adjustable from 16 to 100,000.',
                    errorText: int.tryParse(budgetField.text) == budget
                        ? null
                        : 'Enter a whole number from 16 to 100,000.',
                  ),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    setState(() {
                      if (n != null && n >= 16 && n <= 100000) {
                        budget = n;
                        partIndex = 0;
                      }
                    });
                  },
                ),
                if (profile.codeBlock)
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Discord code block'),
                    subtitle: const Text(
                      'Include a fenced wrapper in each part.',
                    ),
                    value: wrapper,
                    onChanged: (v) => setState(() {
                      wrapper = v;
                      partIndex = 0;
                    }),
                  ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Label message parts'),
                  subtitle: const Text(
                    'Labels count toward each part’s budget.',
                  ),
                  value: labels,
                  onChanged: (v) => setState(() {
                    labels = v;
                    partIndex = 0;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                key: const Key('fit-message'),
                onPressed: !available || busy
                    ? null
                    : () {
                        debounce?.cancel();
                        render(fit: true);
                      },
                icon: const Icon(Icons.fit_screen, size: 18),
                label: const Text('Fit to message'),
              ),
              OutlinedButton.icon(
                key: const Key('keep-detail'),
                onPressed: () {
                  runner.cancel();
                  debounce?.cancel();
                  setState(() {
                    output = c.output;
                    settings = c.settings;
                    renderedSettings = c.settings;
                    busy = false;
                    error = null;
                    partIndex = 0;
                  });
                },
                icon: const Icon(Icons.splitscreen_outlined, size: 18),
                label: const Text('Keep detail / split into parts'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${output.characterCount} characters · ${output.rows} lines · ${whole.length}/$budget units with wrapper',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: WorkIndicator(),
            ),
          if (overBudget)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Tip(
                'This artwork exceeds the configured budget. Fit to a smaller text resolution, or keep every row and copy it in parts. Separate messages can interrupt visual continuity.',
                warning: true,
              ),
            ),
          if (error != null || splitError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Tip(error ?? splitError!, warning: true),
            ),
          const SectionTitle('Approximate destination width'),
          Surface(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Text(
                  '${profile.name} · suggested ${profile.width} columns · illustrative only',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                // Keep glyphs at the suggested cell size. Wide art pans horizontally;
                // it is never silently wrapped or scaled into a pretend app screenshot.
                SizedBox(
                  height: 270,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final font =
                          ((constraints.maxWidth - 24) / profile.width / .6)
                              .clamp(3.0, 18.0);
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ColoredBox(
                          color: Theme.of(context).colorScheme.surface,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  previewText,
                                  softWrap: false,
                                  textScaler: TextScaler.noScaling,
                                  style: TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    fontFamilyFallback: const ['GlyphicaDots'],
                                    fontSize: font,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Scroll to inspect. Actual font, wrapping, and spacing may differ.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (part != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous part',
                  onPressed: partIndex > 0
                      ? () => setState(() => partIndex--)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    'Part ${partIndex.clamp(0, parts.length - 1) + 1} of ${parts.length} · ${part.count} chars · ${part.units} units',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Next part',
                  onPressed: partIndex < parts.length - 1
                      ? () => setState(() => partIndex++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            if (wrapper || labels)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Copy includes ${[if (labels && parts.length > 1) 'Part ${partIndex + 1}/${parts.length}', if (wrapper) 'opening and closing code fences'].join(' and ')}.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => copyArtwork(context, part.formatted),
              icon: const Icon(Icons.copy_outlined, size: 18),
              label: Text(
                parts.length > 1
                    ? 'Copy part ${partIndex + 1}'
                    : 'Copy destination text',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => showExportSheet(
                      context,
                      name: '${c.name}-${profile.id}-part-${partIndex + 1}',
                      text: part.formatted,
                    ),
              icon: const Icon(Icons.ios_share, size: 18),
              label: const Text('Share or save this part'),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy || error != null
                ? null
                : () => safely(context, () async {
                    final latest = app.find(c.id)!;
                    final variant = SavedVariant(
                      destination: profile.id,
                      text: output.text,
                      settings: settings,
                      budget: budget,
                      codeBlock: wrapper,
                      labels: labels,
                    );
                    await app.put(
                      latest.copyWith(
                        variants: [
                          ...latest.variants.where(
                            (v) => v.destination != profile.id,
                          ),
                          variant,
                        ],
                      ),
                    );
                    if (context.mounted) {
                      notice(
                        context,
                        '${profile.name} variant saved separately',
                      );
                    }
                  }),
            icon: const Icon(Icons.bookmark_add_outlined, size: 18),
            label: const Text('Save destination variant'),
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: () =>
                showExportSheet(context, name: c.name, text: c.output.text),
            child: const Text('Export original full-quality .txt'),
          ),
          const SizedBox(height: 12),
          const Tip(
            'The original conversion stays intact. Every part contains complete rows. Artwork is never silently truncated.',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
