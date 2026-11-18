import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:poseit/models/pose.dart';
import 'package:poseit/providers/pose_provider.dart';
import 'package:poseit/theme/app_theme.dart';
import 'package:poseit/screens/pose_grid_screen.dart';
import 'package:poseit/screens/favorites_screen.dart';
import 'package:poseit/screens/settings_screen.dart';
import 'package:poseit/screens/camera_overlay_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onNavigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  void _showCategorySelectionModal(BuildContext context) {
    final poseProvider = Provider.of<PoseProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E222D),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Category',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildCategoryPickerTile(
                      context: context,
                      title: 'Women',
                      subtitle: '${poseProvider.categoryCount(PoseCategory.girl)} poses',
                      category: PoseCategory.girl,
                      color: const Color(0xFFEC407A),
                      icon: Icons.female,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCategoryPickerTile(
                      context: context,
                      title: 'Men',
                      subtitle: '${poseProvider.categoryCount(PoseCategory.boy)} poses',
                      category: PoseCategory.boy,
                      color: const Color(0xFF42A5F5),
                      icon: Icons.male,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildCategoryPickerTile(
                      context: context,
                      title: 'Couples',
                      subtitle: '${poseProvider.categoryCount(PoseCategory.couple)} poses',
                      category: PoseCategory.couple,
                      color: const Color(0xFFAB47BC),
                      icon: Icons.favorite,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCategoryPickerTile(
                      context: context,
                      title: 'Aesthetic',
                      subtitle: '${poseProvider.categoryCount(PoseCategory.aesthetic)} poses',
                      category: PoseCategory.aesthetic,
                      color: const Color(0xFFFF6D00),
                      icon: Icons.auto_awesome,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryPickerTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required PoseCategory category,
    required Color color,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PoseGridScreen(category: category),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTipsAndTricksModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1E222D),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.lightbulb, color: Color(0xFFFFD700), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Posing Tips & Tricks',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Essential photography rules for effortless, natural model poses.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const Divider(color: Colors.white12, height: 28),
                  _buildTipCard(
                    number: '1',
                    title: 'The 45° Angle Rule',
                    desc: 'Never stand completely square to the lens. Turning your hips and shoulders 30°–45° instantly creates a dynamic silhouette and slims the waist.',
                    icon: Icons.screen_rotation,
                  ),
                  _buildTipCard(
                    number: '2',
                    title: 'Give Your Hands a Purpose',
                    desc: 'Awkward hands ruin great photos. Touch your hair, slide fingers into pockets with thumbs out, hold a jacket lapel, or hold coffee/props.',
                    icon: Icons.pan_tool,
                  ),
                  _buildTipCard(
                    number: '3',
                    title: 'Define the Jawline (Turtle Neck)',
                    desc: 'Push your forehead slightly forward and down toward the lens. This tightens the neck skin and creates a razor-sharp, photogenic jawline.',
                    icon: Icons.face,
                  ),
                  _buildTipCard(
                    number: '4',
                    title: 'Shift Weight to Back Leg',
                    desc: 'Place 70% of your body weight on your rear leg. This drops one hip naturally and gives an effortless runway posture.',
                    icon: Icons.directions_walk,
                  ),
                  _buildTipCard(
                    number: '5',
                    title: 'Create Triangular Negative Space',
                    desc: 'Keep elbows slightly away from your sides and knees slightly bent. Triangles between limbs add visual structure and breathing room.',
                    icon: Icons.change_history,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTipCard({
    required String number,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFFFF5252),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _BrowseTab(
            searchController: _searchController,
            onOpenPoses: () => _showCategorySelectionModal(context),
            onOpenTips: () => _showTipsAndTricksModal(context),
            onOpenFavorites: () => _onNavigateToTab(1),
          ),
          const FavoritesScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Browse',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _BrowseTab extends StatelessWidget {
  final TextEditingController searchController;
  final VoidCallback onOpenPoses;
  final VoidCallback onOpenTips;
  final VoidCallback onOpenFavorites;

  const _BrowseTab({
    required this.searchController,
    required this.onOpenPoses,
    required this.onOpenTips,
    required this.onOpenFavorites,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<PoseProvider>(
        builder: (context, poseProvider, _) {
          final isSearching = poseProvider.searchQuery.isNotEmpty;
          return CustomScrollView(
            slivers: [
              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: searchController,
                    onChanged: (value) => poseProvider.setSearchQuery(value),
                    decoration: InputDecoration(
                      hintText: 'Search 90+ poses...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: isSearching
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                poseProvider.setSearchQuery('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),

              if (isSearching) ...[
                _buildSearchResults(context, poseProvider),
              ] else ...[
                // ── Hero Section (Image 1 Left Screen Style) ─────────────────
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.black12, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Title: Posing App (Image 1 Header)
                        const Text(
                          'Posing App',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'sans-serif',
                            color: Color(0xFF232B2F),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'The Posing Guide for Photographers and Models',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        // Center Hand-Drawn Sketch of Models on Couch
                        Container(
                          height: 175,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.black12, width: 1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SvgPicture.asset(
                              'assets/poses/posing_guide_cover.svg',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // 3 Action Buttons (Image 1 Style: Poses, Tips & Tricks, My favorites)
                        _buildMenuButton(
                          label: 'Poses',
                          icon: Icons.photo_library_outlined,
                          onTap: onOpenPoses,
                        ),
                        const SizedBox(height: 10),
                        _buildMenuButton(
                          label: 'Tips & Tricks',
                          icon: Icons.lightbulb_outline,
                          onTap: onOpenTips,
                        ),
                        const SizedBox(height: 10),
                        _buildMenuButton(
                          label: 'My favorites',
                          icon: Icons.favorite_border,
                          onTap: onOpenFavorites,
                        ),
                        const SizedBox(height: 16),

                        // Big Direct SOVS Camera Button
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CameraOverlayScreen(
                                  pose: poseProvider.allPoses.isNotEmpty
                                      ? poseProvider.allPoses.first
                                      : null,
                                  initialPoseList: poseProvider.allPoses,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'OPEN CAMERA GUIDE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Category Cards Grid ───────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      'Browse By Category',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _CategoryCard(
                          category: PoseCategory.girl,
                          displayName: 'Women',
                          count: poseProvider.categoryCount(PoseCategory.girl),
                        ),
                        const SizedBox(height: 10),
                        _CategoryCard(
                          category: PoseCategory.boy,
                          displayName: 'Men',
                          count: poseProvider.categoryCount(PoseCategory.boy),
                        ),
                        const SizedBox(height: 10),
                        _CategoryCard(
                          category: PoseCategory.couple,
                          displayName: 'Couples',
                          count: poseProvider.categoryCount(PoseCategory.couple),
                        ),
                        const SizedBox(height: 10),
                        _CategoryCard(
                          category: PoseCategory.aesthetic,
                          displayName: 'Aesthetic / Gen-Z',
                          count: poseProvider.categoryCount(PoseCategory.aesthetic),
                        ),
                      ],
                    ),
                  ),
                ),

                // Trending Poses Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: _TrendingSection(poses: poseProvider.allPoses),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildMenuButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF4B5563), size: 18),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            const Icon(Icons.arrow_forward_ios, size: 13, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  SliverPadding _buildSearchResults(
      BuildContext context, PoseProvider poseProvider) {
    final results = poseProvider.filteredPoses;
    if (results.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.all(32),
        sliver: SliverToBoxAdapter(
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No poses found',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final pose = results[index];
            return _PoseGridItem(pose: pose);
          },
          childCount: results.length,
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final PoseCategory category;
  final String? displayName;
  final int count;

  const _CategoryCard({
    required this.category,
    this.displayName,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.categoryColor(category.name);
    final icon = AppTheme.categoryIcon(category.name);
    final name = displayName ?? (category.name[0].toUpperCase() + category.name.substring(1));

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PoseGridScreen(category: category),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      '$count poses',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendingSection extends StatelessWidget {
  final List<Pose> poses;

  const _TrendingSection({required this.poses});

  @override
  Widget build(BuildContext context) {
    final trending = poses.take(6).toList();
    if (trending.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Popular Poses',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Icon(Icons.trending_up, color: Color(0xFFFF5252), size: 18),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: trending.length,
            itemBuilder: (context, index) {
              final pose = trending[index];
              return Container(
                width: 120,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CameraOverlayScreen(
                          pose: pose,
                          initialPoseList: poses,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12, width: 1.2),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Expanded(
                          child: SvgPicture.asset(
                            pose.svgAssetPath,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pose.name,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PoseGridItem extends StatelessWidget {
  final Pose pose;

  const _PoseGridItem({required this.pose});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CameraOverlayScreen(pose: pose),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12, width: 1.2),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Expanded(
              child: SvgPicture.asset(
                pose.svgAssetPath,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              pose.name,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
