import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_controller.dart';
import '../../shared/widgets.dart';
import '../export/export_sheet.dart';
import '../history/history_screen.dart';

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool dark = false, compare = false;
  bool? sourceAvailable;
  @override
  void initState() {
    super.initState();
    final c = ref.read(appProvider).find(widget.id);
    if (c != null) {
      File(c.source.path).exists().then((v) {
        if (mounted) setState(() => sourceAvailable = v);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider),
        c = ref.watch(appProvider).find(widget.id);
    if (c == null) {
      return StudioScaffold(
        title: 'Artwork',
        child: EmptyState(
          title: 'Artwork unavailable',
          message: 'It may have been deleted from this device.',
          action: FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Back to studio'),
          ),
        ),
      );
    }
    final output = c.output;
    return StudioScaffold(
      title: 'Your artwork',
      actions: [
        IconButton(
          tooltip: 'Destination presets',
          onPressed: () => context.push('/destination/${c.id}'),
          icon: const Icon(Icons.forum_outlined),
        ),
        IconButton(
          tooltip: 'Home',
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.home_outlined),
        ),
        PopupMenuButton<String>(
          tooltip: 'Artwork actions',
          onSelected: (value) async {
            if (value == 'rename') await renameCreation(context, app, c);
            if (value == 'duplicate' && context.mounted) {
              await safely(context, () async {
                await app.duplicate(c);
                if (context.mounted) notice(context, 'Artwork duplicated');
              });
            }
            if (value == 'delete' &&
                context.mounted &&
                await confirmDelete(context) &&
                context.mounted) {
              await safely(context, () async {
                await app.delete(c.id);
                if (context.mounted) context.go('/history');
              });
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'rename', child: Text('Rename')),
            PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ],
      bottom: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              key: const Key('copy-original'),
              onPressed: () => copyArtwork(context, output.text),
              icon: const Icon(Icons.copy_outlined, size: 18),
              label: const Text('Copy text'),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            key: const Key('export-open'),
            onPressed: () =>
                showExportSheet(context, name: c.name, text: output.text),
            icon: const Icon(Icons.ios_share, size: 18),
            label: const Text('Export'),
          ),
        ],
      ),
      child: ListView(
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              const Eyebrow('04 / An impression, made', accent: true),
              const Spacer(),
              IconButton(
                tooltip: c.favorite ? 'Remove favorite' : 'Favorite',
                onPressed: () => safely(
                  context,
                  () => app.put(c.copyWith(favorite: !c.favorite)),
                ),
                icon: Icon(
                  c.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          Text(c.name, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Chip(label: Text(c.settings.mode.label)),
              Chip(label: Text('${output.columns} × ${output.rows} cells')),
              const Chip(
                avatar: Icon(Icons.check_circle_outline, size: 15),
                label: Text('Saved locally'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${output.characterCount} characters · ${output.rows} lines',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                tooltip: 'Compare with original source',
                onPressed: () => setState(() => compare = !compare),
                icon: Icon(
                  compare ? Icons.view_agenda_outlined : Icons.compare,
                ),
              ),
              IconButton(
                tooltip: dark ? 'Light preview paper' : 'Dark preview paper',
                onPressed: () => setState(() => dark = !dark),
                icon: Icon(
                  dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                ),
              ),
            ],
          ),
          if (compare)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Surface(
                child: Row(
                  children: [
                    SourceThumbnail(c.source, size: 100),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Eyebrow('Original source'),
                          const SizedBox(height: 8),
                          Text(c.source.name),
                          Text(
                            '${c.source.width} × ${c.source.height} px · uncropped',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Surface(
            padding: const EdgeInsets.all(9),
            child: ArtCanvas(
              text: output.text,
              columns: output.columns,
              rows: output.rows,
              height: MediaQuery.sizeOf(context).height.clamp(650, 1000) * .49,
              dark: dark,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Pinch or scroll to zoom · drag to pan · text never wraps',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SourceThumbnail(c.source, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Original conversion'),
                    Text(
                      '${c.settings.width} columns · ${c.settings.dither ? 'dithered' : 'clean tones'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit a new conversion',
                onPressed: sourceAvailable == false
                    ? null
                    : () {
                        app.edit(c);
                        context.push('/prepare');
                      },
                icon: const Icon(Icons.tune),
              ),
            ],
          ),
          if (sourceAvailable == false)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Tip(
                'The source image is unavailable. Saved text and variants remain usable. You can still copy, split, share, and export them.',
                warning: true,
              ),
            ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            key: const Key('destination-open'),
            onPressed: () => context.push('/destination/${c.id}'),
            icon: const Icon(Icons.forum_outlined, size: 18),
            label: const Text('Where will you paste this?'),
          ),
          const SizedBox(height: 12),
          const Tip(
            'Use a monospace font where possible. More detail costs more characters. Destination variants are saved separately from this original.',
          ),
          const SectionTitle('Conversion details'),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Created ${MaterialLocalizations.of(context).formatFullDate(c.createdAt)}',
                ),
                const SizedBox(height: 6),
                Text(
                  'Processed crop: ${output.sourceWidth} × ${output.sourceHeight} px\nBrightness ${(c.settings.brightness * 100).round()}% · Contrast ${(c.settings.contrast * 100).round()}% · Gamma ${c.settings.gamma.toStringAsFixed(2)}\nCell aspect ${c.settings.cellAspect.toStringAsFixed(2)} · Edge ${(c.settings.edge * 100).round()}% · Invert ${c.settings.invert ? 'on' : 'off'}\n${c.variants.length} saved destination variants',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
