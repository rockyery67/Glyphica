import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_controller.dart';
import '../../shared/widgets.dart';
import 'models.dart';

class PrepareScreen extends ConsumerStatefulWidget {
  const PrepareScreen({super.key});
  @override
  ConsumerState<PrepareScreen> createState() => _PrepareScreenState();
}

class _PrepareScreenState extends ConsumerState<PrepareScreen> {
  late ArtSettings settings;
  @override
  void initState() {
    super.initState();
    settings = ref.read(appProvider).draftSettings;
  }

  void rotate(int delta) => setState(() {
    settings = settings.copyWith(
      rotation: (settings.rotation + delta) % 4,
      cropLeft: 0,
      cropTop: 0,
      cropRight: 1,
      cropBottom: 1,
    );
  });

  void crop(double? aspect) {
    final source = ref.read(appProvider).draft!;
    final ratio = settings.rotation.isOdd
        ? source.height / source.width
        : source.width / source.height;
    var w = 1.0, h = 1.0;
    if (aspect != null) {
      if (ratio > aspect) {
        w = aspect / ratio;
      } else {
        h = ratio / aspect;
      }
    }
    setState(
      () => settings = settings.copyWith(
        cropLeft: (1 - w) / 2,
        cropRight: (1 + w) / 2,
        cropTop: (1 - h) / 2,
        cropBottom: (1 + h) / 2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(appProvider).draft;
    if (source == null) {
      return const StudioScaffold(
        child: EmptyState(
          title: 'Choose an image first',
          message: 'Return to Create to import a photo.',
        ),
      );
    }
    final ratio = settings.rotation.isOdd
        ? source.height / source.width
        : source.width / source.height;
    return StudioScaffold(
      title: 'Prepare image',
      bottom: FilledButton.icon(
        key: const Key('prepare-next'),
        onPressed: () {
          ref.read(appProvider).draftSettings = settings;
          context.push('/style');
        },
        icon: const Icon(Icons.arrow_forward, size: 18),
        label: const Text('Choose your characters'),
      ),
      child: ListView(
        children: [
          const SizedBox(height: 12),
          const Eyebrow('01 / Shape the source', accent: true),
          const SizedBox(height: 12),
          Text(
            'Find your frame.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${source.width} × ${source.height} px · orientation corrected',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          Surface(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              height: 310,
              child: Center(
                child: AspectRatio(
                  aspectRatio: ratio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: Color.fromARGB(
                          255,
                          settings.matte,
                          settings.matte,
                          settings.matte,
                        ),
                        child: RotatedBox(
                          quarterTurns: settings.rotation,
                          child: Image.file(
                            File(source.thumbnailPath),
                            fit: BoxFit.fill,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                      CustomPaint(
                        painter: _CropPainter(
                          Rect.fromLTRB(
                            settings.cropLeft,
                            settings.cropTop,
                            settings.cropRight,
                            settings.cropBottom,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Rotate left',
                onPressed: () => rotate(-1),
                icon: const Icon(Icons.rotate_left),
              ),
              Text(
                '${settings.rotation * 90}°',
                style: const TextStyle(fontSize: 12),
              ),
              IconButton(
                key: const Key('rotate-right'),
                tooltip: 'Rotate right',
                onPressed: () => rotate(1),
                icon: const Icon(Icons.rotate_right),
              ),
              const SizedBox(width: 14),
              TextButton.icon(
                onPressed: () => crop(null),
                icon: const Icon(Icons.crop_free, size: 18),
                label: const Text('Reset crop'),
              ),
            ],
          ),
          const SectionTitle('Crop'),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('Original'),
                onPressed: () => crop(null),
              ),
              ActionChip(label: const Text('Square'), onPressed: () => crop(1)),
              ActionChip(
                label: const Text('Portrait 4:5'),
                onPressed: () => crop(4 / 5),
              ),
              ActionChip(
                label: const Text('Wide 16:9'),
                onPressed: () => crop(16 / 9),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Horizontal crop'),
                RangeSlider(
                  values: RangeValues(settings.cropLeft, settings.cropRight),
                  min: 0,
                  max: 1,
                  labels: RangeLabels(
                    '${(settings.cropLeft * 100).round()}%',
                    '${(settings.cropRight * 100).round()}%',
                  ),
                  onChanged: (v) {
                    if (v.end - v.start >= .05) {
                      setState(
                        () => settings = settings.copyWith(
                          cropLeft: v.start,
                          cropRight: v.end,
                        ),
                      );
                    }
                  },
                ),
                const Text('Vertical crop'),
                RangeSlider(
                  values: RangeValues(settings.cropTop, settings.cropBottom),
                  min: 0,
                  max: 1,
                  labels: RangeLabels(
                    '${(settings.cropTop * 100).round()}%',
                    '${(settings.cropBottom * 100).round()}%',
                  ),
                  onChanged: (v) {
                    if (v.end - v.start >= .05) {
                      setState(
                        () => settings = settings.copyWith(
                          cropTop: v.start,
                          cropBottom: v.end,
                        ),
                      );
                    }
                  },
                ),
                Text(
                  'Move either handle to choose the exact crop. The dimmed area is excluded.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SectionTitle('Transparent pixels'),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 255, label: Text('White')),
              ButtonSegment(value: 128, label: Text('Gray')),
              ButtonSegment(value: 0, label: Text('Black')),
            ],
            selected: {settings.matte},
            onSelectionChanged: (v) =>
                setState(() => settings = settings.copyWith(matte: v.first)),
          ),
          const SizedBox(height: 14),
          const Tip(
            'Transparency is composited onto the selected paper before conversion. The original image stays intact.',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.crop);
  final Rect crop;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      crop.left * size.width,
      crop.top * size.height,
      crop.right * size.width,
      crop.bottom * size.height,
    );
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(rect);
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: .55));
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(rect.deflate(.75), border);
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .3)
      ..strokeWidth = .6;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(rect.left + rect.width * i / 3, rect.top),
        Offset(rect.left + rect.width * i / 3, rect.bottom),
        grid,
      );
      canvas.drawLine(
        Offset(rect.left, rect.top + rect.height * i / 3),
        Offset(rect.right, rect.top + rect.height * i / 3),
        grid,
      );
    }
    final handle = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final point in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      final dx = point.dx == rect.left ? 1 : -1,
          dy = point.dy == rect.top ? 1 : -1;
      canvas.drawLine(
        point,
        point + Offset(math.min(16.0, rect.width / 4) * dx, 0),
        handle,
      );
      canvas.drawLine(
        point,
        point + Offset(0, math.min(16.0, rect.height / 4) * dy),
        handle,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) =>
      oldDelegate.crop != crop;
}
