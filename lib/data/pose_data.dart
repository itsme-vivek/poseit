import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/pose.dart';

class PoseData {
  static const String _assetPath = 'assets/data/poses.json';
  static List<Pose>? _cachedPoses;

  /// Loads all poses from the bundled JSON asset.
  /// Results are cached after the first load.
  static Future<List<Pose>> loadPoses([BuildContext? context]) async {
    if (_cachedPoses != null) return _cachedPoses!;

    final jsonString = await rootBundle.loadString(_assetPath);
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

    _cachedPoses = jsonList
        .map((item) => Pose.fromJson(item as Map<String, dynamic>))
        .toList();

    return _cachedPoses!;
  }

  /// Filters the loaded poses by [category].
  static Future<List<Pose>> filterByCategory(PoseCategory category) async {
    final poses = await loadPoses();
    return poses.where((p) => p.category == category).toList();
  }

  /// Searches poses by [query] against name, description, and tags.
  /// Case-insensitive.
  static Future<List<Pose>> searchPoses(String query) async {
    final poses = await loadPoses();
    final q = query.toLowerCase();
    return poses.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          p.tags.any((tag) => tag.toLowerCase().contains(q));
    }).toList();
  }

  /// Returns poses whose [id] is in the given list of [ids].
  static Future<List<Pose>> getFavorites(List<String> ids) async {
    final poses = await loadPoses();
    final idSet = ids.toSet();
    return poses.where((p) => idSet.contains(p.id)).toList();
  }

  /// Filters poses by [difficulty].
  static Future<List<Pose>> filterByDifficulty(PoseDifficulty difficulty) async {
    final poses = await loadPoses();
    return poses.where((p) => p.difficulty == difficulty).toList();
  }

  /// Returns only premium poses.
  static Future<List<Pose>> getPremiumPoses() async {
    final poses = await loadPoses();
    return poses.where((p) => p.isPremium).toList();
  }

  /// Clears the in-memory cache so the next [loadPoses] re-reads the asset.
  static void clearCache() {
    _cachedPoses = null;
  }
}
