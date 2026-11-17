import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:poseit/models/pose.dart';
import 'package:poseit/providers/pose_provider.dart';
import 'package:poseit/theme/app_theme.dart';
import 'package:poseit/screens/pose_grid_screen.dart';
import 'package:poseit/screens/pose_detail_screen.dart';
import 'package:poseit/screens/favorites_screen.dart';
import 'package:poseit/screens/settings_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _BrowseTab(searchController: _searchController),
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

  const _BrowseTab({required this.searchController});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<PoseProvider>(
        builder: (context, poseProvider, _) {
          final isSearching = poseProvider.searchQuery.isNotEmpty;
          return CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                floating: true,
                title: const Text(
                  'PoseIt',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                centerTitle: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined),
                    onPressed: () {},
                  ),
                ],
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: TextField(
                    controller: searchController,
                    onChanged: (value) => poseProvider.setSearchQuery(value),
                    decoration: InputDecoration(
                      hintText: 'Search poses...',
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
                          .withOpacity(0.5),
                    ),
                  ),
                ),
              ),

              // Content: Search results or browse categories
              if (isSearching) ...[
                _buildSearchResults(context, poseProvider),
              ] else ...[
                // Category Cards
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Categories',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _CategoryCard(
                          category: PoseCategory.boy,
                          count: poseProvider.categoryCount(PoseCategory.boy),
                        ),
                        const SizedBox(height: 12),
                        _CategoryCard(
                          category: PoseCategory.girl,
                          count: poseProvider.categoryCount(PoseCategory.girl),
                        ),
                        const SizedBox(height: 12),
                        _CategoryCard(
                          category: PoseCategory.couple,
                          count: poseProvider.categoryCount(PoseCategory.couple),
                        ),
                        const SizedBox(height: 12),
                        _CategoryCard(
                          category: PoseCategory.aesthetic,
                          count: poseProvider.categoryCount(PoseCategory.aesthetic),
                        ),
                      ],
                    ),
                  ),
                ),

                // Trending Poses
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: _TrendingSection(poses: poseProvider.allPoses),
                  ),
                ),

                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 16),
                ),
              ],
            ],
          );
        },
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
  final int count;

  const _CategoryCard({required this.category, required this.count});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.categoryColor(category.name);
    final icon = AppTheme.categoryIcon(category.name);
    final name = category.name[0].toUpperCase() + category.name.substring(1);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PoseGridScreen(category: category),
          ),
        );
      },
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color,
              color.withOpacity(0.7),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: Colors.white),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '$count poses',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.7),
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
    if (poses.isEmpty) return const SizedBox.shrink();

    // Pick 6 random poses
    final random = Random();
    final shuffled = List<Pose>.from(poses)..shuffle(random);
    final trending = shuffled.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Trending Poses',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: trending.length,
            itemBuilder: (context, index) {
              final pose = trending[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PoseDetailScreen(
                        pose: pose,
                        posesInCategory: poses
                            .where((p) => p.category == pose.category)
                            .toList(),
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Container(
                            color: AppTheme.categoryColor(pose.category.name)
                                .withOpacity(0.1),
                            padding: const EdgeInsets.all(12),
                            child: SvgPicture.asset(
                              pose.svgAssetPath,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
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
                              const SizedBox(height: 2),
                              Text(
                                pose.category.name[0].toUpperCase() +
                                    pose.category.name.substring(1),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.categoryColor(
                                      pose.category.name),
                                ),
                              ),
                            ],
                          ),
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
    final poseProvider = Provider.of<PoseProvider>(context);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PoseDetailScreen(
              pose: pose,
              posesInCategory: poseProvider
                  .posesByCategory(pose.category),
            ),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: AppTheme.categoryColor(pose.category.name)
                    .withOpacity(0.1),
                padding: const EdgeInsets.all(8),
                child: Hero(
                  tag: pose.id,
                  child: SvgPicture.asset(
                    pose.svgAssetPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              AppTheme.difficultyColor(pose.difficulty.name)
                                  .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          pose.difficulty.name,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.difficultyColor(
                                pose.difficulty.name),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (pose.isPremium) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.star,
                          size: 14,
                          color: AppTheme.premiumGold,
                        ),
                      ],
                    ],
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
