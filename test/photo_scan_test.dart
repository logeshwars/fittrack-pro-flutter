import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:fittrack_pro/features/nutrition/data/photo_scan_service.dart';
import 'package:fittrack_pro/features/nutrition/domain/food_result.dart';
import 'package:fittrack_pro/features/nutrition/domain/photo_scan_models.dart';

void main() {
  test('PhotoScanResult parses items and converts to per-100g', () {
    final r = PhotoScanResult.fromJson({
      'items': [
        {
          'food_name': 'Dal',
          'estimated_grams': 200,
          'protein_g': 14,
          'carbs_g': 36,
          'fat_g': 1,
          'fiber_g': 6,
          'calories': 210,
          'confidence': 0.8,
          'micronutrients': {'iron_mg': 4, 'zinc_mg': 0},
        }
      ],
      'scansUsed': 2,
      'scansLimit': 10,
    });
    expect(r.items.single.foodName, 'Dal');
    expect(r.items.single.micronutrients, {'iron_mg': 4.0});
    final per100 = r.items.single.toFoodResult();
    expect(per100.proteinPer100g, 7);
    expect(scaleFood(per100, 100).calories, 105);
  });

  test('legacy single-item response is wrapped', () {
    final r = PhotoScanResult.fromJson({'food_name': 'Egg', 'protein_g': 6});
    expect(r.items.length, 1);
    expect(r.items.first.estimatedGrams, 200);
    expect(r.scansLimit, 10);
  });

  test('compressForUpload downsizes wide images, keeps small ones', () {
    final big = Uint8List.fromList(img.encodePng(img.Image(width: 1600, height: 800)));
    final out = img.decodeJpg(compressForUpload(big))!;
    expect(out.width, 800);
    expect(out.height, 400);
    final small = Uint8List.fromList(img.encodePng(img.Image(width: 300, height: 200)));
    expect(img.decodeJpg(compressForUpload(small))!.width, 300);
    expect(() => compressForUpload(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<PhotoScanFailure>()));
  });
}
