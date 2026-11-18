import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:poseit/models/pose.dart';
import 'package:poseit/providers/pose_provider.dart';
import 'package:poseit/providers/settings_provider.dart';
import 'package:poseit/theme/app_theme.dart';
import 'package:poseit/screens/camera_overlay_screen.dart';
import 'package:poseit/screens/pose_detail_screen.dart';

class PoseGridScreen extends StatefulWidget {
  final PoseCategory category;

  const PoseGridScreen({super.key, required this.category});

  @override
  State<PoseGridScreen> createState() => _PoseGridScreenState();
}

class _PoseGridScreenState extends State<PoseGridScreen> {
  PoseDifficulty? _selectedDifficulty;

  String get _displayCategoryName {
    switch (widget.category) {
      case PoseCategory.girl:
        return 'Women';
      case PoseCategory.boy:
        return 'Men';
      case PoseCategory.couple:
        return 'Couples';
      case PoseCategory.aesthetic:
        return 'Aesthetic';
    }
  }

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
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E222D),
        foregroundColor: Colors.white,
        elevation: 1,
        title: Text(
          _displayCategoryName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        leading: TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.only(left: 6),
          ),
          icon: const Icon(Icons.arrow_back_ios, size: 14),
          label: const Text('Poses', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          onPressed: () => Navigator.pop(context),
        ),
        leadingWidth: 88,
        actions: [
          IconButton(
            tooltip: 'Open Camera',
            icon: const Icon(Icons.camera_alt, color: Color(0xFFFF5252)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CameraOverlayScreen(
                    pose: poses.isNotEmpty ? poses.first : null,
                    initialPoseList: poseProvider.posesByCategory(widget.category),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    label: 'All (${poseProvider.posesByCategory(widget.category).length})',
                    selected: _selectedDifficulty == null,
                    onSelected: () {
                      setState(() => _selectedDifficulty = null);
                    },
                  ),
                  const SizedBox(width: 8),
                  ...PoseDifficulty.values.map((difficulty) {
                    final diffLabel = difficulty.name[0].toUpperCase() +
                        difficulty.name.substring(1);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildFilterChip(
                        label: diffLabel,
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
          ),

          // 2-Column Clean Sketch Grid (Image 1 right side style)
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
                      childAspectRatio: 0.76,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
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
      selectedColor: const Color(0xFFFF5252).withValues(alpha: 0.2),
      checkmarkColor: const Color(0xFFFF5252),
      backgroundColor: const Color(0xFFF0F0F2),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFFFF5252) : Colors.black87,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
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
        // Tapping opens the SOVS-style camera directly with this pose active and category strip loaded!
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CameraOverlayScreen(
              pose: pose,
              initialPoseList: allCategoryPoses,
            ),
          ),
        );
      },
      onLongPress: () {
        // Long press opens details screen
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
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black26, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Line art sketch inside framed container (Image 1 right phone)
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 26),
                child: Hero(
                  tag: 'pose_${pose.id}',
                  child: SvgPicture.asset(
                    pose.svgAssetPath,
                    fit: BoxFit.contain,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF232B2F),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),

            // Favorite button (top-right)
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => poseProvider.toggleFavorite(pose.id),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? Colors.redAccent : Colors.black45,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),

            // Camera shortcut indicator (top-left)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt, size: 10, color: Color(0xFFFF5252)),
                    SizedBox(width: 2),
                    Text(
                      'TAP',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF5252),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Pose title bar (bottom)
            Positioned(
              bottom: 4,
              left: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6F8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  pose.name,
                  style: const TextStyle(
                    color: Color(0xFF2C3437),
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
