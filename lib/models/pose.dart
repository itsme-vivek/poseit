
enum PoseCategory { boy, girl, couple, aesthetic }

enum PoseDifficulty { easy, medium, advanced }

class Pose {
  final String id;
  final String name;
  final PoseCategory category;
  final PoseDifficulty difficulty;
  final String description;
  final List<String> instructions;
  final String svgAssetPath;
  final List<String> tips;
  final List<String> tags;
  final bool isPremium; // for monetization

  const Pose({
    required this.id,
    required this.name,
    required this.category,
    required this.difficulty,
    required this.description,
    required this.instructions,
    required this.svgAssetPath,
    this.tips = const [],
    this.tags = const [],
    this.isPremium = false,
  });

  /// Returns the path to the AI cartoon preview image for this pose.
  /// Falls back gracefully if the preview has not yet been generated.
  String get cartoonPreviewPath =>
      'assets/poses/previews/${category.name}/$id.png';

  factory Pose.fromJson(Map<String, dynamic> json) {
    return Pose(
      id: json['id'] as String,
      name: json['name'] as String,
      category: PoseCategory.values.firstWhere(
        (e) => e.name == json['category'],
      ),
      difficulty: PoseDifficulty.values.firstWhere(
        (e) => e.name == json['difficulty'],
      ),
      description: json['description'] as String,
      instructions: List<String>.from(json['instructions'] as List),
      svgAssetPath: json['svgAsset'] as String,
      tips: json['tips'] != null ? List<String>.from(json['tips'] as List) : [],
      tags: json['tags'] != null ? List<String>.from(json['tags'] as List) : [],
      isPremium: json['isPremium'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'difficulty': difficulty.name,
    'description': description,
    'instructions': instructions,
    'svgAsset': svgAssetPath,
    'tips': tips,
    'tags': tags,
    'isPremium': isPremium,
  };
}
