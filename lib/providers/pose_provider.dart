import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pose.dart';
import '../data/pose_data.dart';

class PoseProvider with ChangeNotifier {
  List<Pose> _allPoses = [];
  List<String> _favoriteIds = [];
  PoseCategory? _selectedCategory;
  String _searchQuery = '';
  bool _isLoading = true;

  List<Pose> get allPoses => _allPoses;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  PoseCategory? get selectedCategory => _selectedCategory;

  List<Pose> get filteredPoses {
    var poses = _allPoses;
    if (_selectedCategory != null) {
      poses = poses.where((p) => p.category == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      poses = poses.where((p) =>
        p.name.toLowerCase().contains(query) ||
        p.description.toLowerCase().contains(query) ||
        p.tags.any((t) => t.toLowerCase().contains(query))
      ).toList();
    }
    return poses;
  }

  List<Pose> get favoritePoses =>
    _allPoses.where((p) => _favoriteIds.contains(p.id)).toList();

  List<Pose> posesByCategory(PoseCategory category) =>
    _allPoses.where((p) => p.category == category).toList();

  List<Pose> posesByCategoryAndDifficulty(PoseCategory category, PoseDifficulty difficulty) =>
    _allPoses.where((p) => p.category == category && p.difficulty == difficulty).toList();

  bool isFavorite(String poseId) => _favoriteIds.contains(poseId);

  int categoryCount(PoseCategory category) =>
    _allPoses.where((p) => p.category == category).length;

  Future<void> loadPoses(BuildContext context) async {
    _isLoading = true;
    notifyListeners();
    _allPoses = await PoseData.loadPoses(context);
    await _loadFavorites();
    _isLoading = false;
    notifyListeners();
  }

  void setCategory(PoseCategory? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> toggleFavorite(String poseId) async {
    if (_favoriteIds.contains(poseId)) {
      _favoriteIds.remove(poseId);
    } else {
      _favoriteIds.add(poseId);
    }
    notifyListeners();
    await _saveFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    _favoriteIds = prefs.getStringList('favorite_poses') ?? [];
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_poses', _favoriteIds);
  }
}
