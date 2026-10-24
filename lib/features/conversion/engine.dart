import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'models.dart';
import 'ramp_calibration.dart';

class ConversionException implements Exception {
  const ConversionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A bounded, deterministic pipeline with no Flutter or network dependency.
class ArtEngine {
  static const maxEncodedBytes = 24 * 1024 * 1024;
  static const maxPixels = 16000000;
  static const maxCells = 160000;

  img.Image decode(Uint8List bytes) {
    img.Decoder.defaultMaxPixels = maxPixels;
    if (bytes.length > maxEncodedBytes) {
      throw const ConversionException(
        'This file is larger than 24 MB. Resize it locally and try again.',
      );
    }
    final decoder = img.findDecoderForData(bytes);
    if (decoder == null ||
        !{
          img.ImageFormat.png,
          img.ImageFormat.jpg,
          img.ImageFormat.webp,
        }.contains(decoder.format)) {
      throw const ConversionException(
        'Choose a PNG, JPEG, or WebP image. HEIC and other formats are not decoded by this app.',
      );
    }
    final info = decoder.startDecode(bytes);
    if (info == null || info.width <= 0 || info.height <= 0) {
      throw const ConversionException(
        'The image header could not be read. Try a different file.',
      );
    }
    if (info.width * info.height > maxPixels ||
        info.width > 16000 ||
        info.height > 16000) {
      throw const ConversionException(
        'This image exceeds the 16 megapixel memory limit. Resize it locally and try again.',
      );
    }
    // Only the first frame of animated PNG/WebP is decoded.
    final decoded = decoder.decodeFrame(0);
    if (decoded == null) {
      throw const ConversionException(
        'The image is damaged or uses an unsupported encoding.',
      );
    }
    return img
        .bakeOrientation(decoded)
        .convert(format: img.Format.uint8, numChannels: 4);
  }

  Inspection inspect(Uint8List bytes) {
    final source = decode(bytes);
    final thumb = img.copyResize(
      source,
      width: source.width >= source.height ? 640 : null,
      height: source.height > source.width ? 640 : null,
      interpolation: img.Interpolation.average,
    );
    return Inspection(source.width, source.height, img.encodePng(thumb));
  }

  img.Image prepare(img.Image source, ArtSettings s) {
    var image = source;
    if (s.rotation % 4 != 0) {
      image = img.copyRotate(image, angle: (s.rotation % 4) * 90);
    }
    final l = (s.cropLeft.clamp(0.0, 0.98) * image.width).floor();
    final t = (s.cropTop.clamp(0.0, 0.98) * image.height).floor();
    final r = (s.cropRight.clamp(s.cropLeft + 0.01, 1.0) * image.width)
        .ceil()
        .clamp(l + 1, image.width);
    final b = (s.cropBottom.clamp(s.cropTop + 0.01, 1.0) * image.height)
        .ceil()
        .clamp(t + 1, image.height);
    return img.copyCrop(image, x: l, y: t, width: r - l, height: b - t);
  }

  ArtOutput convert(Uint8List bytes, ArtSettings settings) =>
      render(prepare(decode(bytes), settings), settings);

  ArtOutput render(img.Image prepared, ArtSettings s) {
    if (s.width < 8 ||
        s.width > 240 ||
        s.cellAspect < 0.25 ||
        s.cellAspect > 1 ||
        s.gamma <= 0 ||
        !s.gamma.isFinite ||
        !s.contrast.isFinite ||
        !s.brightness.isFinite) {
      throw const ConversionException(
        'Invalid output settings. Reset the controls and try again.',
      );
    }
    final cols = s.width;
    final rows = math.max(
      1,
      (prepared.height / prepared.width * cols * s.cellAspect).round(),
    );
    if (cols * rows > maxCells) {
      throw const ConversionException(
        'This crop would create too many text cells. Reduce the width or use a wider crop.',
      );
    }
    final braille = s.mode == ArtMode.braille;
    final w = cols * (braille ? 2 : 1), h = rows * (braille ? 4 : 1);
    // Composite alpha BEFORE resampling; invisible RGB never leaks into edges.
    final matte = s.matte.clamp(0, 255);
    final opaque = img.Image(
      width: prepared.width,
      height: prepared.height,
      numChannels: 3,
    );
    for (final p in prepared) {
      final a = p.a / 255;
      opaque.setPixelRgb(
        p.x,
        p.y,
        p.r * a + matte * (1 - a),
        p.g * a + matte * (1 - a),
        p.b * a + matte * (1 - a),
      );
    }
    final small = img.copyResize(
      opaque,
      width: w,
      height: h,
      interpolation: w < opaque.width || h < opaque.height
          ? img.Interpolation.average
          : img.Interpolation.cubic,
    );
    final tones = Float64List(w * h);
    for (final p in small) {
      // Linear-light Rec.709 luminance, encoded back to perceptual sRGB.
      final y =
          0.2126 * _linear(p.r / 255) +
          0.7152 * _linear(p.g / 255) +
          0.0722 * _linear(p.b / 255);
      var v = _srgb(y);
      v = ((v - 0.5) * s.contrast + 0.5 + s.brightness).clamp(0.0, 1.0);
      v = math.pow(v, 1 / s.gamma).toDouble();
      tones[p.y * w + p.x] = s.invert ? 1 - v : v;
    }
    if (s.edge > 0) {
      final base = Float64List.fromList(tones);
      final amount = s.edge.clamp(0.0, 0.6);
      for (var y = 1; y < h - 1; y++) {
        for (var x = 1; x < w - 1; x++) {
          final i = y * w + x;
          final blur =
              (base[i - 1] +
                  base[i + 1] +
                  base[i - w] +
                  base[i + w] +
                  base[i] * 4) /
              8;
          // A capped unsharp mask keeps halos and noise under control.
          final delta = ((base[i] - blur) * amount * 2).clamp(-0.12, 0.12);
          tones[i] = (base[i] + delta).clamp(0.0, 1.0);
        }
      }
    }
    final text = braille
        ? _braille(tones, w, h, s.dither)
        : _characters(tones, w, h, s);
    return ArtOutput(
      text: text,
      columns: cols,
      rows: rows,
      sourceWidth: prepared.width,
      sourceHeight: prepared.height,
    );
  }

  static double _linear(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  static double _srgb(double v) =>
      v <= 0.0031308 ? v * 12.92 : 1.055 * math.pow(v, 1 / 2.4) - 0.055;

  static String? validateRamp(String ramp) {
    final codes = ramp.runes.toList();
    if (codes.length < 2 || codes.length > 96 || codes.toSet().length < 2) {
      return 'Use 2–96 characters with at least two different glyphs, light to dense.';
    }
    for (final c in codes) {
      if (!((c >= 32 && c <= 126) ||
          (c >= 0x2500 && c <= 0x259f) ||
          (c >= 0x2800 && c <= 0x28ff))) {
        return 'Use printable ASCII, box/block, or Braille glyphs. Emoji, tabs, newlines, and combining marks cannot form reliable cells.';
      }
    }
    return null;
  }

  String _characters(Float64List tones, int w, int h, ArtSettings s) {
    final List<String> glyphs;
    final List<double> levels;
    if (s.mode == ArtMode.custom) {
      final error = validateRamp(s.customRamp);
      if (error != null) throw ConversionException(error);
      glyphs = s.customRamp.runes.map(String.fromCharCode).toList();
      levels = List.generate(glyphs.length, (i) => i / (glyphs.length - 1));
    } else if (s.mode == ArtMode.blocks) {
      glyphs = [' ', '░', '▒', '▓', '█'];
      levels = [0, 0.25, 0.5, 0.75, 1];
    } else {
      final ramp = s.mode == ArtMode.classic
          ? classicCalibration
          : detailedCalibration;
      glyphs = ramp.map((e) => e.$1).toList();
      levels = ramp.map((e) => e.$2).toList();
    }
    final out = StringBuffer();
    for (var y = 0; y < h; y++) {
      if (y > 0) out.write('\n');
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        final darkness = (1 - tones[i]).clamp(0.0, 1.0);
        var nearest = 0;
        var difference = double.infinity;
        for (var n = 0; n < levels.length; n++) {
          final d = (levels[n] - darkness).abs();
          if (d < difference) {
            difference = d;
            nearest = n;
          }
        }
        out.write(glyphs[nearest]);
        if (s.dither) {
          _diffuse(tones, w, h, x, y, (1 - darkness) - (1 - levels[nearest]));
        }
      }
    }
    return out.toString();
  }

  String _braille(Float64List tones, int w, int h, bool dither) {
    final dots = List<bool>.filled(w * h, false);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        final v = tones[i].clamp(0.0, 1.0);
        dots[i] = v < 0.5;
        if (dither) _diffuse(tones, w, h, x, y, v - (dots[i] ? 0 : 1));
      }
    }
    final out = StringBuffer();
    for (var y = 0; y < h; y += 4) {
      if (y > 0) out.write('\n');
      for (var x = 0; x < w; x += 2) {
        var bits = 0;
        // Unicode dots: left 1,2,3,7; right 4,5,6,8.
        const masks = [
          [1, 8],
          [2, 16],
          [4, 32],
          [64, 128],
        ];
        for (var dy = 0; dy < 4; dy++) {
          for (var dx = 0; dx < 2; dx++) {
            if (dots[(y + dy) * w + x + dx]) bits |= masks[dy][dx];
          }
        }
        out.writeCharCode(0x2800 + bits);
      }
    }
    return out.toString();
  }

  void _diffuse(Float64List v, int w, int h, int x, int y, double error) {
    void add(int xx, int yy, double fraction) {
      if (xx >= 0 && xx < w && yy < h) v[yy * w + xx] += error * fraction;
    }

    add(x + 1, y, 7 / 16);
    add(x - 1, y + 1, 3 / 16);
    add(x, y + 1, 5 / 16);
    add(x + 1, y + 1, 1 / 16);
  }
}
