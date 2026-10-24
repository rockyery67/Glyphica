import 'dart:typed_data';

enum ArtMode {
  classic('Classic ASCII', 'A timeless ten-character palette', ' .:-=+*#%@'),
  detailed(
    'Detailed ASCII',
    'Fine tonal steps for richer shading',
    ' .,:;ilxoa#MW&%@',
  ),
  blocks('Unicode blocks', 'Bold shapes and soft stepped tones', ' ░▒▓█'),
  braille(
    'Unicode Braille',
    'Eight dots. Remarkably fine contours.',
    '⠀⠁⠃⠇⡇⣇⣧⣷⣿',
  ),
  custom('Custom ramp', 'Your own sequence, from light to dense', ' .:-=+*#%@');

  const ArtMode(this.label, this.description, this.ramp);
  final String label;
  final String description;
  final String ramp;
}

enum QualityLook { silhouette, shading, detail }

class ArtSettings {
  const ArtSettings({
    this.mode = ArtMode.detailed,
    this.width = 100,
    this.cellAspect = 0.5,
    this.brightness = 0,
    this.contrast = 1.15,
    this.gamma = 1,
    this.invert = false,
    this.dither = false,
    this.edge = 0.15,
    this.customRamp = ' .:-=+*#%@',
    this.rotation = 0,
    this.cropLeft = 0,
    this.cropTop = 0,
    this.cropRight = 1,
    this.cropBottom = 1,
    this.matte = 255,
  });

  final ArtMode mode;
  final int width;

  /// Physical width / height of a rendered character cell.
  final double cellAspect;
  final double brightness, contrast, gamma, edge;
  final bool invert, dither;
  final String customRamp;
  final int rotation;

  /// Normalized crop in the upright image AFTER quarter-turn rotation.
  final double cropLeft, cropTop, cropRight, cropBottom;
  final int matte;

  ArtSettings copyWith({
    ArtMode? mode,
    int? width,
    double? cellAspect,
    double? brightness,
    double? contrast,
    double? gamma,
    bool? invert,
    bool? dither,
    double? edge,
    String? customRamp,
    int? rotation,
    double? cropLeft,
    double? cropTop,
    double? cropRight,
    double? cropBottom,
    int? matte,
  }) => ArtSettings(
    mode: mode ?? this.mode,
    width: width ?? this.width,
    cellAspect: cellAspect ?? this.cellAspect,
    brightness: brightness ?? this.brightness,
    contrast: contrast ?? this.contrast,
    gamma: gamma ?? this.gamma,
    invert: invert ?? this.invert,
    dither: dither ?? this.dither,
    edge: edge ?? this.edge,
    customRamp: customRamp ?? this.customRamp,
    rotation: rotation ?? this.rotation,
    cropLeft: cropLeft ?? this.cropLeft,
    cropTop: cropTop ?? this.cropTop,
    cropRight: cropRight ?? this.cropRight,
    cropBottom: cropBottom ?? this.cropBottom,
    matte: matte ?? this.matte,
  );

  ArtSettings withLook(QualityLook look) => switch (look) {
    QualityLook.silhouette => copyWith(
      mode: ArtMode.classic,
      contrast: 1.65,
      gamma: 1,
      edge: 0.3,
      dither: false,
    ),
    QualityLook.shading => copyWith(
      mode: ArtMode.detailed,
      contrast: 1.05,
      gamma: 1,
      edge: 0,
      dither: true,
    ),
    QualityLook.detail => copyWith(
      mode: ArtMode.detailed,
      contrast: 1.15,
      gamma: 1,
      edge: 0.2,
      dither: false,
    ),
  };

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'width': width,
    'cellAspect': cellAspect,
    'brightness': brightness,
    'contrast': contrast,
    'gamma': gamma,
    'invert': invert,
    'dither': dither,
    'edge': edge,
    'customRamp': customRamp,
    'rotation': rotation,
    'cropLeft': cropLeft,
    'cropTop': cropTop,
    'cropRight': cropRight,
    'cropBottom': cropBottom,
    'matte': matte,
  };

  factory ArtSettings.fromJson(Map<String, dynamic> j) => ArtSettings(
    mode: ArtMode.values.firstWhere(
      (m) => m.name == j['mode'],
      orElse: () => ArtMode.classic,
    ),
    width: (j['width'] as num?)?.toInt() ?? 100,
    cellAspect: (j['cellAspect'] as num?)?.toDouble() ?? 0.5,
    brightness: (j['brightness'] as num?)?.toDouble() ?? 0,
    contrast: (j['contrast'] as num?)?.toDouble() ?? 1.15,
    gamma: (j['gamma'] as num?)?.toDouble() ?? 1,
    invert: j['invert'] == true,
    dither: j['dither'] == true,
    edge: (j['edge'] as num?)?.toDouble() ?? 0.15,
    customRamp: j['customRamp'] as String? ?? ' .:-=+*#%@',
    rotation: (j['rotation'] as num?)?.toInt() ?? 0,
    cropLeft: (j['cropLeft'] as num?)?.toDouble() ?? 0,
    cropTop: (j['cropTop'] as num?)?.toDouble() ?? 0,
    cropRight: (j['cropRight'] as num?)?.toDouble() ?? 1,
    cropBottom: (j['cropBottom'] as num?)?.toDouble() ?? 1,
    matte: (j['matte'] as num?)?.toInt() ?? 255,
  );
}

class ArtOutput {
  const ArtOutput({
    required this.text,
    required this.columns,
    required this.rows,
    required this.sourceWidth,
    required this.sourceHeight,
  });
  final String text;
  final int columns, rows, sourceWidth, sourceHeight;
  int get characterCount => text.runes.length;
  int get utf16Count => text.length;
}

class SourceImage {
  const SourceImage({
    required this.id,
    required this.name,
    required this.path,
    required this.thumbnailPath,
    required this.width,
    required this.height,
  });
  final String id, name, path, thumbnailPath;
  final int width, height;
}

class Inspection {
  const Inspection(this.width, this.height, this.thumbnail);
  final int width, height;
  final Uint8List thumbnail;
}
