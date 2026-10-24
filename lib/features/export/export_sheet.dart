import 'package:flutter/material.dart';

import '../../core/output_service.dart';
import '../../shared/widgets.dart';
import '../../shared/work_indicator.dart';

Future<void> showExportSheet(
  BuildContext context, {
  required String name,
  required String text,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : null,
  builder: (_) => ExportSheet(name: name, text: text),
);

class ExportSheet extends StatefulWidget {
  const ExportSheet({super.key, required this.name, required this.text});
  final String name, text;
  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  bool busy = false;
  String? status;
  Future<void> action(Future<String?> Function() run) async {
    setState(() {
      busy = true;
      status = null;
    });
    try {
      final message = await run();
      if (mounted) setState(() => status = message);
    } catch (e) {
      if (mounted) {
        setState(() => status = 'Could not complete this action: $e');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Take your characters with you', accent: true),
            const SizedBox(height: 12),
            Text(
              'A little art. Anywhere.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(
              '${widget.text.runes.length} characters · ${widget.text.split('\n').length} lines · UTF-8',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 22),
            ListTile(
              enabled: !busy,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy text'),
              subtitle: const Text('Spaces and line breaks stay intact'),
              onTap: () => action(() async {
                await OutputService().copy(widget.text);
                return 'Copied with all whitespace preserved.';
              }),
            ),
            ListTile(
              key: const Key('save-txt'),
              enabled: !busy,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('Save .txt file'),
              subtitle: Text(OutputService.filename(widget.name)),
              onTap: () => action(() async {
                final uri = await OutputService().export(
                  widget.name,
                  widget.text,
                );
                return uri == null
                    ? 'Save cancelled. No file was saved.'
                    : 'UTF-8 artwork saved to the location you selected.';
              }),
            ),
            ListTile(
              key: const Key('share-text'),
              enabled: !busy,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.ios_share),
              title: const Text('Share text'),
              subtitle: const Text(
                'Choose a destination in the OS share sheet',
              ),
              onTap: () => action(() async {
                await OutputService().shareText(context, widget.text);
                return null;
              }),
            ),
            ListTile(
              key: const Key('share-file'),
              enabled: !busy,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Share .txt file'),
              subtitle: const Text('Send the full artwork as a UTF-8 document'),
              onTap: () => action(() async {
                await OutputService().shareFile(
                  context,
                  widget.name,
                  widget.text,
                );
                return null;
              }),
            ),
            if (busy) const WorkIndicator(),
            if (status != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  status!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 16),
            const Tip(
              'Sharing opens your device’s share sheet. Nothing is sent automatically. Destination apps may wrap rows or change spacing.',
            ),
          ],
        ),
      ),
    ),
  );
}
