import '../conversion/models.dart';

class SavedVariant {
  const SavedVariant({
    required this.destination,
    required this.text,
    required this.settings,
    required this.budget,
    required this.codeBlock,
    required this.labels,
  });
  final String destination, text;
  final ArtSettings settings;
  final int budget;
  final bool codeBlock, labels;
  Map<String, dynamic> toJson() => {
    'destination': destination,
    'text': text,
    'settings': settings.toJson(),
    'budget': budget,
    'codeBlock': codeBlock,
    'labels': labels,
  };
  factory SavedVariant.fromJson(Map<String, dynamic> j) => SavedVariant(
    destination: j['destination'],
    text: j['text'],
    settings: ArtSettings.fromJson(j['settings']),
    budget: j['budget'],
    codeBlock: j['codeBlock'],
    labels: j['labels'],
  );
}

class Creation {
  const Creation({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.source,
    required this.output,
    required this.settings,
    this.favorite = false,
    this.variants = const [],
  });
  final String id, name;
  final DateTime createdAt;
  final SourceImage source;
  final ArtOutput output;
  final ArtSettings settings;
  final bool favorite;
  final List<SavedVariant> variants;

  Creation copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    bool? favorite,
    List<SavedVariant>? variants,
  }) => Creation(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    source: source,
    output: output,
    settings: settings,
    favorite: favorite ?? this.favorite,
    variants: variants ?? this.variants,
  );
}
