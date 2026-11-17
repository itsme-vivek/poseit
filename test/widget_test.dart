import 'package:flutter_test/flutter_test.dart';
import 'package:poseit/models/pose.dart';
import 'package:image/image.dart' as img;

void main() {
  test('Pose model deserializes correctly with aesthetic category', () {
    final json = {
      'id': 'aesthetic_001',
      'name': '0.5x Distorted Selfie',
      'category': 'aesthetic',
      'difficulty': 'easy',
      'description': 'Gen-Z selfie',
      'instructions': ['Hold high', 'Tilt face up'],
      'svgAsset': 'assets/poses/aesthetic/zero_point_five_selfie.svg',
      'tips': ['Flash on'],
      'tags': ['0.5x', 'gen-z'],
      'isPremium': false,
    };

    final pose = Pose.fromJson(json);

    expect(pose.id, 'aesthetic_001');
    expect(pose.category, PoseCategory.aesthetic);
    expect(pose.difficulty, PoseDifficulty.easy);
    expect(pose.instructions.length, 2);
  });

  test('Image processing test for Y2K date stamp and filters', () {
    final image = img.Image(width: 400, height: 400);
    img.fill(image, color: img.ColorRgb8(50, 50, 50));
    
    final gray = img.grayscale(image);
    expect(gray.width, 400);

    img.drawString(
      gray,
      "'26 11 17",
      font: img.arial24,
      x: 100,
      y: 350,
      color: img.ColorRgb8(255, 138, 0),
    );

    final jpg = img.encodeJpg(gray, quality: 90);
    expect(jpg.isNotEmpty, true);
  });
}
