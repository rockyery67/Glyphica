import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_controller.dart';
import '../../core/theme.dart';
import '../../shared/widgets.dart';
import '../../shared/work_indicator.dart';
import '../history/history_screen.dart';

Future<void> startImport(
  BuildContext context,
  WidgetRef ref,
  ImportKind kind,
) async {
  await safely(context, () async {
    final source = await ref.read(appProvider).importImage(kind);
    if (source != null && context.mounted) context.push('/prepare');
  });
}

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => StudioScaffold(
    bottom: FilledButton.icon(
      key: const Key('welcome-start'),
      onPressed: () => safely(context, () async {
        await ref.read(appProvider).setPreference('welcomed', 'true');
        if (context.mounted) context.go('/');
      }),
      icon: const Icon(Icons.arrow_forward, size: 19),
      label: const Text('Enter the studio'),
    ),
    child: MotionEntry(
      child: ListView(
        children: [
          const SizedBox(height: 24),
          const Eyebrow('Images, reimagined in type', accent: true),
          const SizedBox(height: 14),
          Text(
            'A new language\nfor your images.',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.2,
                  child: Image.asset(
                    'assets/samples/philosopher.png',
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ink,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'LIGHT → GLYPHS → ART',
                      style: TextStyle(
                        fontFamily: mono,
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Less pixels. More character.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Turn photographs into ASCII, blocks, or delicate Braille dots. Shape the tone, find your style, and take the text anywhere.',
          ),
          const SizedBox(height: 22),
          const Row(
            children: [
              Icon(Icons.offline_bolt_outlined, size: 19),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Entirely on your device. No account. No uploads.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await safely(context, () async {
        final recovered = await ref.read(appProvider).recoverPicker();
        if (recovered && mounted) {
          notice(context, 'Recovered your selected image');
          context.push('/prepare');
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final colors = Theme.of(context).colorScheme;
    return StudioScaffold(
      tab: 0,
      child: MotionEntry(
        child: ListView(
          children: [
            const SizedBox(height: 12),
            Row(
              children: [
                const Eyebrow('Your offline text atelier', accent: true),
                const Spacer(),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colors.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'LOCAL',
                  style: TextStyle(fontFamily: mono, fontSize: 9),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Make an\nimpression.',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 10),
            Text(
              'Your images. A different kind of expression.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            Surface(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Start with an image',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Find the art hidden between light and shade.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [Eyebrow('PNG   /   JPEG   /   WEBP')],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('import-photos'),
                      onPressed: app.importing
                          ? null
                          : () => startImport(context, ref, ImportKind.photos),
                      icon: const Icon(Icons.photo_library_outlined, size: 19),
                      label: Text(
                        app.importing ? 'Reading image…' : 'Choose from photos',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          key: const Key('import-files'),
                          onPressed: app.importing
                              ? null
                              : () =>
                                    startImport(context, ref, ImportKind.files),
                          icon: const Icon(Icons.folder_open, size: 19),
                          label: const Text('Browse files'),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed:
                              app.importing ||
                                  !(Platform.isAndroid || Platform.isIOS)
                              ? null
                              : () => startImport(
                                  context,
                                  ref,
                                  ImportKind.camera,
                                ),
                          icon: const Icon(
                            Icons.photo_camera_outlined,
                            size: 19,
                          ),
                          label: const Text('Camera'),
                        ),
                      ),
                    ],
                  ),
                  if (app.importing) const WorkIndicator(),
                ],
              ),
            ),
            const SectionTitle(
              'A little inspiration',
              trailing: Eyebrow('Try it offline', accent: true),
            ),
            InkWell(
              key: const Key('sample-import'),
              borderRadius: BorderRadius.circular(20),
              onTap: app.importing
                  ? null
                  : () => startImport(context, ref, ImportKind.sample),
              child: Surface(
                padding: EdgeInsets.zero,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(20),
                      ),
                      child: Image.asset(
                        'assets/samples/philosopher.png',
                        width: 118,
                        height: 146,
                        fit: BoxFit.cover,
                        cacheWidth: 300,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Eyebrow('Study no. 01', accent: true),
                            const SizedBox(height: 9),
                            Text(
                              'The philosopher',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Stone, shadow & character',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 10),
                            const Row(
                              children: [
                                Text(
                                  'Make it yours',
                                  style: TextStyle(fontSize: 12),
                                ),
                                SizedBox(width: 7),
                                Icon(Icons.arrow_forward, size: 16),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SectionTitle(
              'Recent conversions',
              trailing: TextButton(
                onPressed: () => context.go('/history'),
                child: const Text('View all →'),
              ),
            ),
            if (app.creations.isEmpty)
              const EmptyState(
                title: 'A fresh canvas',
                message: 'Your completed artwork will be saved here automatically. Start with a photo or the sample above.',
              ),
            ...app.creations
                .take(3)
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CreationCard(c),
                  ),
                ),
            const SizedBox(height: 8),
            const Tip(
              'Strong light and a simple background make a good first impression. More columns reveal more detail, but create longer messages.',
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
