import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:poseit/models/pose.dart';
import 'package:poseit/providers/pose_provider.dart';
import 'package:poseit/theme/app_theme.dart';
import 'package:poseit/screens/camera_overlay_screen.dart';

class PoseDetailScreen extends StatefulWidget {
  final Pose pose;
  final List<Pose> posesInCategory;

  const PoseDetailScreen({
    super.key,
    required this.pose,
    required this.posesInCategory,
  });

  @override
  State<PoseDetailScreen> createState() => _PoseDetailScreenState();
}

class _PoseDetailScreenState extends State<PoseDetailScreen> {
  late PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.posesInCategory
        .indexWhere((p) => p.id == widget.pose.id)
        .clamp(0, widget.posesInCategory.length - 1);
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.posesInCategory.length,
        onPageChanged: (index) {
          setState(() => _currentPage = index);
        },
        itemBuilder: (context, index) {
          final pose = widget.posesInCategory[index];
          return _PoseDetailContent(pose: pose);
        },
      ),
    );
  }
}

class _PoseDetailContent extends StatelessWidget {
  final Pose pose;

  const _PoseDetailContent({required this.pose});

  void _sharePose() {
    final instructions = pose.instructions
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');
    final text =
        '📸 ${pose.name}\n\n${pose.description}\n\n📋 Instructions:\n$instructions\n\nShared from PoseIt app';
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    final poseProvider = Provider.of<PoseProvider>(context);
    final isFav = poseProvider.isFavorite(pose.id);
    final categoryColor = AppTheme.categoryColor(pose.category.name);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // SVG Hero Image
          SliverAppBar(
            expandedHeight: 350,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: categoryColor.withOpacity(0.08),
                child: Hero(
                  tag: pose.id,
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: SvgPicture.asset(
                        pose.svgAssetPath,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row
                  Text(
                    pose.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),

                  // Badges
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              AppTheme.difficultyColor(pose.difficulty.name)
                                  .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          pose.difficulty.name[0].toUpperCase() +
                              pose.difficulty.name.substring(1),
                          style: TextStyle(
                            color: AppTheme.difficultyColor(
                                pose.difficulty.name),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (pose.isPremium) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.premiumGold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star,
                                  size: 16, color: AppTheme.premiumGold),
                              SizedBox(width: 4),
                              Text(
                                'Premium',
                                style: TextStyle(
                                  color: AppTheme.premiumGold,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Description
                  Text(
                    pose.description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 24),

                  // Instructions
                  _SectionHeader(icon: Icons.format_list_numbered, title: 'Instructions'),
                  const SizedBox(height: 12),
                  ...pose.instructions.asMap().entries.map((entry) {
                    return _InstructionTile(
                      index: entry.key + 1,
                      text: entry.value,
                    );
                  }),
                  const SizedBox(height: 24),

                  // Pro Tips
                  if (pose.tips.isNotEmpty) ...[
                    _SectionHeader(icon: Icons.lightbulb_outline, title: 'Pro Tips'),
                    const SizedBox(height: 12),
                    ...pose.tips.map((tip) => _TipTile(text: tip)),
                    const SizedBox(height: 24),
                  ],

                  // Tags
                  if (pose.tags.isNotEmpty) ...[
                    _SectionHeader(icon: Icons.label_outline, title: 'Tags'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: pose.tags.map((tag) {
                        return Chip(
                          label: Text(
                            tag,
                            style: const TextStyle(fontSize: 12),
                          ),
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 100), // bottom padding for action bar
                ],
              ),
            ),
          ),
        ],
      ),

      // Bottom Action Bar
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Favorite button
              IconButton.filled(
                onPressed: () => poseProvider.toggleFavorite(pose.id),
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? Colors.red : null,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: isFav
                      ? Colors.red.withOpacity(0.1)
                      : Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                ),
              ),
              const SizedBox(width: 12),

              // Try with Camera
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CameraOverlayScreen(pose: pose),
                      ),
                    );
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Try with Camera'),
                ),
              ),
              const SizedBox(width: 12),

              // Share button
              IconButton.filled(
                onPressed: _sharePose,
                icon: const Icon(Icons.share),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

class _InstructionTile extends StatelessWidget {
  final int index;
  final String text;

  const _InstructionTile({required this.index, required this.text});

  IconData _getDirectionIcon(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('↑') || lower.contains('up')) return Icons.arrow_upward;
    if (lower.contains('↓') || lower.contains('down')) return Icons.arrow_downward;
    if (lower.contains('←') || lower.contains('left')) return Icons.arrow_back;
    if (lower.contains('→') || lower.contains('right')) return Icons.arrow_forward;
    return Icons.chevron_right;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$index',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            _getDirectionIcon(text),
            size: 18,
            color: AppTheme.accentColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipTile extends StatelessWidget {
  final String text;

  const _TipTile({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb,
            size: 20,
            color: AppTheme.premiumGold,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
