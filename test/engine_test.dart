import 'dart:typed_data';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:glyphica/features/conversion/engine.dart';
import 'package:glyphica/features/conversion/models.dart';
import 'package:glyphica/features/conversion/ramp_calibration.dart';

Uint8List solid(
  int r,
  int g,
  int b, {
  int alpha = 255,
  int width = 40,
  int height = 40,
}) {
  final source = img.Image(width: width, height: height, numChannels: 4);
  img.fill(source, color: img.ColorRgba8(r, g, b, alpha));
  return img.encodePng(source);
}

void main() {
  final engine = ArtEngine();
  const clean = ArtSettings(
    mode: ArtMode.classic,
    width: 40,
    contrast: 1,
    edge: 0,
  );

  test('square image retains physical aspect with half-width cells', () {
    final out = engine.convert(solid(0, 0, 0), clean);
    expect(out.columns, 40);
    expect(out.rows, 20);
    expect(out.text.split('\n').every((r) => r.length == 40), isTrue);
    expect(out.characterCount, 40 * 20 + 19);
  });

  test('local WebP fixture decodes and renders without a platform codec', () {
    final bytes = File('test/fixtures/format.webp').readAsBytesSync();
    final out = engine.convert(bytes, clean);
    expect(out.sourceWidth, 320);
    expect(out.sourceHeight, 320);
    expect(out.text.split('\n').length, 20);
  });

  test('JPEG EXIF orientation is baked before dimensions and crop', () {
    final image = img.Image(width: 80, height: 40);
    img.fill(image, color: img.ColorRgb8(200, 100, 20));
    image.exif.imageIfd.orientation = 6;
    final encoded = img.encodeJpg(image);
    final decoded = engine.decode(encoded);
    expect(decoded.width, 40);
    expect(decoded.height, 80);
    final out = engine.convert(encoded, clean);
    expect(out.rows, 40);
    final rotated = engine.convert(encoded, clean.copyWith(rotation: 1));
    expect(rotated.sourceWidth, 80);
    expect(rotated.sourceHeight, 40);
    expect(rotated.rows, 10);
  });

  test('all eight EXIF orientations position the expected corner', () {
    const corner = {1: 4, 2: 2, 3: 7, 4: 1, 5: 4, 6: 1, 7: 7, 8: 2};
    for (var orientation = 1; orientation <= 8; orientation++) {
      final source = img.Image(width: 32, height: 16);
      for (final p in source) {
        final left = p.x < 16, top = p.y < 8;
        p.setRgb(
          left && top || !left && !top ? 255 : 0,
          !left ? 255 : 0,
          !top ? 255 : 0,
        );
      }
      source.exif.imageIfd.orientation = orientation;
      final upright = engine.decode(img.encodeJpg(source, quality: 100));
      expect(upright.width, orientation >= 5 ? 16 : 32);
      expect(upright.height, orientation >= 5 ? 32 : 16);
      final pixel = upright.getPixel(3, 3);
      final rgb =
          (pixel.r > 128 ? 4 : 0) |
          (pixel.g > 128 ? 2 : 0) |
          (pixel.b > 128 ? 1 : 0);
      expect(rgb, corner[orientation], reason: 'EXIF $orientation');
    }
  });

  test('normalized crop is applied after rotation', () {
    final out = engine.convert(
      solid(0, 0, 0, width: 80, height: 40),
      clean.copyWith(rotation: 1, cropTop: .25, cropBottom: .75),
    );
    expect(out.sourceWidth, 40);
    expect(out.sourceHeight, 40);
    expect(out.rows, 20);
  });

  test('white and black map to measured ramp endpoints', () {
    final white = engine.convert(solid(255, 255, 255), clean);
    final black = engine.convert(solid(0, 0, 0), clean);
    expect(white.text.split('\n').every((r) => r == ' ' * 40), isTrue);
    expect(
      black.text.split('\n').every((r) => r == classicCalibration.last.$1 * 40),
      isTrue,
    );
    expect(
      engine.convert(solid(0, 0, 0), clean.copyWith(invert: true)).text,
      white.text,
    );
  });

  test('transparent invisible RGB is composited before filtering', () {
    final transparent = solid(0, 0, 0, alpha: 0);
    expect(
      engine.convert(transparent, clean).text,
      engine.convert(solid(255, 255, 255), clean).text,
    );
    expect(
      engine.convert(transparent, clean.copyWith(matte: 0)).text,
      engine.convert(solid(0, 0, 0), clean).text,
    );
    expect(
      engine.convert(solid(255, 0, 0, alpha: 0), clean).text,
      engine.convert(transparent, clean).text,
    );
  });

  test('brightness, gamma, and perceptual hue luminance affect mapping', () {
    final s = clean.copyWith(mode: ArtMode.custom, customRamp: ' .:-=+*#%@');
    final mid = solid(120, 120, 120);
    expect(
      engine.convert(mid, s.copyWith(brightness: .3)).text,
      isNot(engine.convert(mid, s).text),
    );
    expect(
      engine.convert(mid, s.copyWith(gamma: 1.8)).text,
      isNot(engine.convert(mid, s).text),
    );
    final red = engine.convert(solid(255, 0, 0), s).text.codeUnitAt(0);
    final green = engine.convert(solid(0, 255, 0), s).text.codeUnitAt(0);
    expect(red, isNot(green));
  });

  test('Braille encodes each of the eight spatial dots correctly', () {
    const masks = [
      [1, 8],
      [2, 16],
      [4, 32],
      [64, 128],
    ];
    for (var y = 0; y < 4; y++) {
      for (var x = 0; x < 2; x++) {
        final image = img.Image(width: 16, height: 4);
        img.fill(image, color: img.ColorRgb8(255, 255, 255));
        image.setPixelRgb(x, y, 0, 0, 0);
        final out = engine.render(
          image,
          clean.copyWith(mode: ArtMode.braille, width: 8),
        );
        expect(out.rows, 1);
        expect(out.text.runes.first, 0x2800 + masks[y][x]);
        expect(out.text.runes.skip(1).every((v) => v == 0x2800), isTrue);
      }
    }
  });

  test(
    'Braille solid black is all eight dots and dimensions stay consistent',
    () {
      final out = engine.convert(
        solid(0, 0, 0),
        clean.copyWith(mode: ArtMode.braille),
      );
      expect(out.text.split('\n').every((r) => r == '⣿' * 40), isTrue);
    },
  );

  test('area averaging preserves mixed subpixels rather than aliasing', () {
    final image = img.Image(width: 80, height: 40);
    for (final p in image) {
      final v = p.x.isEven ? 0 : 255;
      p.setRgb(v, v, v);
    }
    final out = engine.render(image, clean.copyWith(width: 40));
    expect(out.text.replaceAll('\n', '').split('').toSet().length, 1);
    expect(out.text[0], isNot(' '));
    expect(out.text[0], isNot(classicCalibration.last.$1));
  });

  test('all modes produce consistent complete rows, with dithering', () {
    final image = img.Image(width: 100, height: 60);
    for (final p in image) {
      p.setRgb(p.x * 255 / 99, p.y * 255 / 59, 80);
    }
    for (final mode in ArtMode.values) {
      final out = engine.render(
        image,
        clean.copyWith(mode: mode, dither: true, edge: .6),
      );
      expect(out.text.split('\n').length, out.rows);
      expect(
        out.text.split('\n').every((r) => r.runes.length == out.columns),
        isTrue,
      );
    }
  });

  test(
    'custom ramp keeps significant spaces and rejects unreliable glyphs',
    () {
      expect(ArtEngine.validateRamp(' .#'), isNull);
      expect(ArtEngine.validateRamp(' .😀'), isNotNull);
      expect(ArtEngine.validateRamp('a\nb'), isNotNull);
      expect(ArtEngine.validateRamp('aa'), isNotNull);
      final out = engine.convert(
        solid(0, 0, 0),
        clean.copyWith(mode: ArtMode.custom, customRamp: ' .#'),
      );
      expect(out.text[0], '#');
    },
  );

  test('unsupported and oversized inputs produce recoverable errors', () {
    expect(
      () => engine.decode(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<ConversionException>()),
    );
    expect(
      () => engine.decode(Uint8List(ArtEngine.maxEncodedBytes + 1)),
      throwsA(isA<ConversionException>()),
    );
    expect(
      () => engine.convert(
        solid(0, 0, 0, width: 2, height: 100),
        clean.copyWith(width: 240),
      ),
      throwsA(isA<ConversionException>()),
    );
  });
}
