import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PoseOverlay extends StatelessWidget {
  final String svgAssetPath;
  final double opacity;
  final Offset offset;
  final double scale;
  final Function(Offset newOffset)? onPositionChanged;
  final Function(double newScale)? onScaleChanged;

  const PoseOverlay({
    super.key,
    required this.svgAssetPath,
    required this.opacity,
    this.offset = Offset.zero,
    this.scale = 1.0,
    this.onPositionChanged,
    this.onScaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Transform.translate(
        offset: offset,
        child: Transform.scale(
          scale: scale,
          child: IgnorePointer(
            ignoring: true,
            child: Opacity(
              opacity: opacity,
              child: Center(
                child: SvgPicture.asset(
                  svgAssetPath,
                  fit: BoxFit.contain,
                  width: MediaQuery.of(context).size.width * 0.85,
                  height: MediaQuery.of(context).size.height * 0.7,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
