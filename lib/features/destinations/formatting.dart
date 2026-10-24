import '../conversion/models.dart';

class DestinationProfile {
  const DestinationProfile({
    required this.id,
    required this.name,
    required this.width,
    required this.budget,
    required this.unicode,
    required this.codeBlock,
    required this.guidance,
    this.formatSource,
  });
  final String id, name, guidance;
  final String? formatSource;
  final int width, budget;
  final bool unicode, codeBlock;
  factory DestinationProfile.fromJson(Map<String, dynamic> j) =>
      DestinationProfile(
        id: j['id'],
        name: j['name'],
        width: j['width'],
        budget: j['budget'],
        unicode: j['unicode'],
        codeBlock: j['codeBlock'],
        guidance: j['guidance'],
        formatSource: j['formatSource'],
      );
  ArtMode get preferredMode => unicode ? ArtMode.blocks : ArtMode.classic;
}

class MessagePart {
  const MessagePart(this.raw, this.formatted);
  final String raw, formatted;
  int get count => formatted.runes.length;
  int get units => formatted.length;
}

class MessageFormatter {
  /// Budgets use conservative UTF-16 units so a surrogate pair is never undercounted.
  static String wrap(String text, {bool codeBlock = false, String? label}) {
    final body = codeBlock ? '```\n$text\n```' : text;
    return label == null ? body : '$label\n$body';
  }

  static List<MessagePart> split(
    String text, {
    required int budget,
    bool codeBlock = false,
    bool labels = false,
  }) {
    if (budget < 16) {
      throw const FormatException('Use a message budget of at least 16.');
    }
    if (codeBlock && text.contains('```')) {
      throw const FormatException(
        'This ramp contains a code fence. Turn off the code-block wrapper to preserve the artwork.',
      );
    }
    final whole = wrap(text, codeBlock: codeBlock);
    if (whole.length <= budget) return [MessagePart(text, whole)];
    final lines = text.split('\n');
    final groups = <String>[];
    var current = <String>[];
    // Reserve labels with the maximum possible digit count. The final count
    // can only shrink, so no part can exceed its budget when labels are applied.
    final maxTotal = lines.length;
    int size(String raw, int index) => wrap(
      raw,
      codeBlock: codeBlock,
      label: labels ? 'Part $index/$maxTotal' : null,
    ).length;
    for (final line in lines) {
      final candidate = [...current, line].join('\n');
      if (size(candidate, groups.length + 1) > budget) {
        if (current.isEmpty) {
          throw const FormatException(
            'A complete row exceeds this budget. Use Fit to message, increase the budget, or export the full .txt file.',
          );
        }
        groups.add(current.join('\n'));
        current = [line];
        if (size(line, groups.length + 1) > budget) {
          throw const FormatException(
            'A complete row exceeds this budget. Reduce the width or export .txt.',
          );
        }
      } else {
        current.add(line);
      }
    }
    if (current.isNotEmpty) groups.add(current.join('\n'));
    return List.generate(
      groups.length,
      (i) => MessagePart(
        groups[i],
        wrap(
          groups[i],
          codeBlock: codeBlock,
          label: labels ? 'Part ${i + 1}/${groups.length}' : null,
        ),
      ),
    );
  }
}
