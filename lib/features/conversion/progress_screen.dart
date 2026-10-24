import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_controller.dart';
import '../../shared/widgets.dart';
import 'worker.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});
  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  final runner = ConversionRunner();
  String? error;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => generate());
  }

  Future<void> generate() async {
    final app = ref.read(appProvider), source = ref.read(appProvider).draft;
    if (source == null) {
      setState(() => error = 'Import an image to begin.');
      return;
    }
    setState(() => error = null);
    try {
      final render = await runner.run<RenderBundle>(
        WorkRequest(source.path, app.draftSettings),
      );
      if (!mounted || render == null) return;
      setState(() => saving = true);
      final creation = await app.saveRender(source, render);
      if (mounted) context.go('/result/${creation.id}');
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    runner.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced =
        ref.watch(appProvider).reduceMotion ||
        MediaQuery.disableAnimationsOf(context);
    return PopScope(
      canPop: !saving,
      child: StudioScaffold(
        title: 'Creating your artwork',
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 76),
              const SizedBox(height: 30),
              const Eyebrow('03 / Light becomes language', accent: true),
              const SizedBox(height: 16),
              Text(
                error != null
                    ? 'A small interruption.'
                    : saving
                    ? 'Keeping your creation.'
                    : 'Finding the right characters.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(
                error ??
                    (saving
                        ? 'Saving the original text, settings, and local source.'
                        : 'Decoding, shaping tones, and composing complete rows. All on this device.'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 28),
              if (error == null)
                reduced
                    ? const Icon(Icons.hourglass_bottom, size: 24)
                    : const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
              if (error != null)
                FilledButton(
                  onPressed: generate,
                  child: const Text('Try again'),
                ),
              const SizedBox(height: 22),
              TextButton(
                key: const Key('cancel-conversion'),
                onPressed: saving
                    ? null
                    : () {
                        runner.cancel();
                        context.pop();
                      },
                child: Text(
                  error == null ? 'Cancel conversion' : 'Back to controls',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
