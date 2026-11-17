import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:poseit/models/pose.dart';
import 'package:poseit/providers/pose_provider.dart';
import 'package:poseit/providers/settings_provider.dart';
import 'package:poseit/theme/app_theme.dart';
import 'package:poseit/screens/pose_detail_screen.dart';

class PoseGridScreen extends StatefulWidget {
  final PoseCategory category;

  const PoseGridScreen({super.key, required this.category});

  @override
  State<PoseGridScreen> createState() => _PoseGridScreenState();
}

class _PoseGridScreenState extends State<PoseGridScreen> {
  PoseDifficulty? _selectedDifficulty;

  String get _categoryName =>
      widget.category.name[0].toUpperCase() + widget.category.name.substring(1);

  @override
  Widget build(BuildContext context) {
    final poseProvider = Provider.of<PoseProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    List<Pose> poses = poseProvider.posesByCategory(widget.category);
    if (_selectedDifficulty != null) {
      poses = poses
          .where((p) => p.difficulty == _selectedDifficulty)
          .toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_categoryName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'All',
                  selected: _selectedDifficulty == null,
                  onSelected: () {
                    setState(() => _selectedDifficulty = null);
                  },
                ),
                const SizedBox(width: 8),
                ...PoseDifficulty.values.map((difficulty) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildFilterChip(
                      label: difficulty.name[0].toUpperCase() +
                          difficulty.name.substring(1),
                      selected: _selectedDifficulty == difficulty,
                      color: AppTheme.difficultyColor(difficulty.name),
                      onSelected: () {
                        setState(() => _selectedDifficulty = difficulty);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          // Grid
          Expanded(
            child: poses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No poses found',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: settingsProvider.gridColumns,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: poses.length,
                    itemBuilder: (context, index) {
                      final pose = poses[index];
                      return _PoseGridCard(
                        pose: pose,
                        allCategoryPoses:
                            poseProvider.posesByCategory(widget.category),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    Color? color,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: (color ?? AppTheme.primaryColor).withOpacity(0.2),
      checkmarkColor: color ?? AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: selected
            ? (color ?? AppTheme.primaryColor)
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

class _PoseGridCard extends StatelessWidget {
  final Pose pose;
  final List<Pose> allCategoryPoses;

  const _PoseGridCard({
    required this.pose,
    required this.allCategoryPoses,
  });

  @override
  Widget build(BuildContext context) {
    final poseProvider = Provider.of<PoseProvider>(context);
    final isFav = poseProvider.isFavorite(pose.id);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PoseDetailScreen(
              pose: pose,
              posesInCategory: allCategoryPoses,
            ),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SVG Thumbnail
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    color: AppTheme.categoryColor(pose.category.name)
                        .withOpacity(0.08),
                    padding: const EdgeInsets.all(12),
                    child: Hero(
                      tag: pose.id,
                      child: SvgPicture.asset(
                        pose.svgAssetPath,
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  // Premium badge
                  if (pose.isPremium)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.premiumGold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 12, color: Colors.white),
                            SizedBox(width: 2),
                            Text(
                              'PRO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Favorite button
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? Colors.red : Colors.grey,
                        size: 20,
                      ),
                      onPressed: () => poseProvider.toggleFavorite(pose.id),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pose.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.difficultyColor(pose.difficulty.name)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      pose.difficulty.name[0].toUpperCase() +
                          pose.difficulty.name.substring(1),
                      style: TextStyle(
                        fontSize: 10,
                        color:
                            AppTheme.difficultyColor(pose.difficulty.name),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
