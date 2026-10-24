import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_controller.dart';
import '../../core/theme.dart';
import '../../shared/widgets.dart';
import 'creation.dart';

Future<bool> confirmDelete(BuildContext context, {bool all = false}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(all ? 'Clear all history?' : 'Delete this artwork?'),
        content: Text(
          all
              ? 'All saved text, variants, and their local images will be removed. Export anything you want to keep first.'
              : 'This removes the saved text, its destination variants, and any unshared local source image.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(all ? 'Clear history' : 'Delete'),
          ),
        ],
      ),
    ) ??
    false;

Future<void> renameCreation(
  BuildContext context,
  AppController app,
  Creation c,
) async {
  final controller = TextEditingController(text: c.name);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Name your artwork'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              Navigator.pop(context, controller.text.trim());
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  // Dispose after the dialog's exit transition has released its editable field.
  Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
  if (name != null && context.mounted) {
    await safely(context, () => app.put(c.copyWith(name: name)));
  }
}

class CreationCard extends ConsumerWidget {
  const CreationCard(this.creation, {super.key});
  final Creation creation;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = creation;
    final date = MaterialLocalizations.of(context).formatShortDate(c.createdAt);
    return InkWell(
      onTap: () => context.push('/result/${c.id}'),
      borderRadius: BorderRadius.circular(20),
      child: Surface(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                SourceThumbnail(c.source),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${c.output.columns} cols · ${c.settings.mode.label}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(date, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: c.favorite ? 'Remove favorite' : 'Favorite',
                  onPressed: () => safely(
                    context,
                    () => ref
                        .read(appProvider)
                        .put(c.copyWith(favorite: !c.favorite)),
                  ),
                  icon: Icon(
                    c.favorite
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: c.favorite
                        ? Theme.of(context).colorScheme.secondary
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRect(
              child: SizedBox(
                height: 26,
                width: double.infinity,
                child: Text(
                  c.output.text
                      .split('\n')
                      .skip(c.output.rows ~/ 3)
                      .take(3)
                      .join('\n'),
                  maxLines: 3,
                  softWrap: false,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: mono,
                    fontFamilyFallback: ['GlyphicaDots'],
                    fontSize: 6,
                    height: 1.3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${c.output.characterCount} characters',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Artwork options',
                  onSelected: (value) async {
                    final app = ref.read(appProvider);
                    if (value == 'rename') {
                      await renameCreation(context, app, c);
                    }
                    if (value == 'duplicate' && context.mounted) {
                      await safely(context, () => app.duplicate(c));
                    }
                    if (value == 'delete' &&
                        context.mounted &&
                        await confirmDelete(context) &&
                        context.mounted) {
                      await safely(context, () => app.delete(c.id));
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(70, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: () => copyArtwork(context, c.output.text),
                  icon: const Icon(Icons.copy_outlined, size: 15),
                  label: const Text('Copy'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String search = '';
  bool favorites = false;
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final items = app.creations
        .where(
          (c) =>
              (!favorites || c.favorite) &&
              ('${c.name} ${c.settings.mode.label}').toLowerCase().contains(
                search.toLowerCase(),
              ),
        )
        .toList();
    return StudioScaffold(
      tab: 1,
      actions: [
        IconButton(
          tooltip: 'Clear history',
          onPressed: app.creations.isEmpty
              ? null
              : () async {
                  if (await confirmDelete(context, all: true) &&
                      context.mounted) {
                    await safely(context, app.clear);
                  }
                },
          icon: const Icon(Icons.delete_sweep_outlined),
        ),
      ],
      child: ListView(
        children: [
          const SizedBox(height: 16),
          const Eyebrow('The collection', accent: true),
          const SizedBox(height: 12),
          Text(
            'Made of character.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${app.creations.length} ${app.creations.length == 1 ? 'creation' : 'creations'}, kept on this device.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 22),
          TextField(
            key: const Key('history-search'),
            decoration: const InputDecoration(
              hintText: 'Search your artwork',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (s) => setState(() => search = s),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All creations'),
                selected: !favorites,
                onSelected: (_) => setState(() => favorites = false),
              ),
              ChoiceChip(
                label: const Text('Favorites'),
                selected: favorites,
                onSelected: (_) => setState(() => favorites = true),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (items.isEmpty)
            EmptyState(
              title: search.isEmpty && !favorites
                  ? 'Your collection starts here'
                  : 'No matching artwork',
              message: search.isEmpty && !favorites
                  ? 'Convert an image to save your first piece. Everything stays on this device.'
                  : 'Try another search or switch to all creations.',
              action: search.isEmpty && !favorites
                  ? FilledButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Create something'),
                    )
                  : null,
            ),
          ...items.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CreationCard(c),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
