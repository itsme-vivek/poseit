import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:poseit/models/pose.dart';
import 'package:poseit/providers/pose_provider.dart';
import 'package:poseit/theme/app_theme.dart';
import 'package:poseit/widgets/difficulty_badge.dart';

class PoseCard extends StatefulWidget {
  final Pose pose;
  final VoidCallback onTap;

  const PoseCard({
    super.key,
    required this.pose,
    required this.onTap,
  });

  @override
  State<PoseCard> createState() => _PoseCardState();
}

class _PoseCardState extends State<PoseCard> with SingleTickerProviderStateMixin {
  /// Tracks whether we're showing the AI cartoon preview (true)
  /// or the line-art SVG silhouette (false).
  bool _showCartoon = true;
  late AnimationController _flipController;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleView() {
    setState(() {
      _showCartoon = !_showCartoon;
      if (_showCartoon) {
        _flipController.reverse();
      } else {
        _flipController.forward();
      }
    });
  }

  /// Category-specific background gradient for the card image area.
  List<Color> get _cardGradient {
    switch (widget.pose.category) {
      case PoseCategory.boy:
        return [const Color(0xFF1A1A2E), const Color(0xFF16213E)];
      case PoseCategory.girl:
        return [const Color(0xFF2D1B33), const Color(0xFF1A1A2E)];
      case PoseCategory.couple:
        return [const Color(0xFF1C1C1C), const Color(0xFF2C1810)];
      case PoseCategory.aesthetic:
        return [const Color(0xFF0D1117), const Color(0xFF161B22)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final poseProvider = context.watch<PoseProvider>();
    final isFav = poseProvider.isFavorite(widget.pose.id);

    return Card(
      elevation: 3,
      shadowColor: Colors.black38,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Image Area ────────────────────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.92, end: 1.0)
                            .animate(animation),
                        child: child,
                      ),
                    ),
                    child: _showCartoon
                        ? _CartoonPreview(
                            key: const ValueKey('cartoon'),
                            pose: widget.pose,
                            gradient: _cardGradient,
                          )
                        : _SvgSilhouette(
                            key: const ValueKey('svg'),
                            pose: widget.pose,
                            gradient: _cardGradient,
                          ),
                  ),

                  // ── View Toggle Pill (bottom-left) ────────────────────
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: GestureDetector(
                      onTap: _toggleView,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _showCartoon
                              ? Colors.white.withValues(alpha: 0.15)
                              : AppTheme.accentColor.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _showCartoon
                                ? Colors.white24
                                : AppTheme.accentColor,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showCartoon
                                  ? Icons.person_outline
                                  : Icons.auto_awesome,
                              size: 10,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _showCartoon ? 'GUIDE' : 'AI ART',
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Favorite Button (top-right) ───────────────────────
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => poseProvider.toggleFavorite(widget.pose.id),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav ? Colors.redAccent : Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Premium Badge (top-left) ──────────────────────────
                  if (widget.pose.isPremium)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.premiumGold,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                            )
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 10, color: Colors.black87),
                            SizedBox(width: 2),
                            Text(
                              'PRO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Pose Name & Difficulty ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.pose.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  DifficultyBadge(difficulty: widget.pose.difficulty),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Cartoon Preview Widget
// Shows the generated PNG cartoon character.
// Falls back to a placeholder if the image hasn't been generated yet.
// ─────────────────────────────────────────────────────────────────────────────
class _CartoonPreview extends StatelessWidget {
  final Pose pose;
  final List<Color> gradient;

  const _CartoonPreview({super.key, required this.pose, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      padding: const EdgeInsets.all(6),
      child: Hero(
        tag: 'pose_${pose.id}',
        child: Image.asset(
          pose.cartoonPreviewPath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) {
            // Graceful fallback: show SVG silhouette with AI label
            return Stack(
              children: [
                Center(
                  child: SvgPicture.asset(
                    pose.svgAssetPath,
                    fit: BoxFit.contain,
                    colorFilter: ColorFilter.mode(
                      Colors.white.withValues(alpha: 0.6),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '✨ Generating...',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SVG Line-Art Silhouette Widget
// The original camera guide overlay silhouette.
// ─────────────────────────────────────────────────────────────────────────────
class _SvgSilhouette extends StatelessWidget {
  final Pose pose;
  final List<Color> gradient;

  const _SvgSilhouette({super.key, required this.pose, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradient,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: SvgPicture.asset(
        pose.svgAssetPath,
        fit: BoxFit.contain,
      ),
    );
  }
}
