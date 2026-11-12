import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/photo_scan_models.dart';

/// The daily AI-scan quota was exhausted (HTTP 429).
class ScanLimitReached implements Exception {
  const ScanLimitReached();
  @override
  String toString() => 'Daily scan limit reached';
}

/// The scan could not be completed.
class PhotoScanFailure implements Exception {
  const PhotoScanFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Resizes to 800 px wide (never upscales) and encodes JPEG q80.
Uint8List compressForUpload(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const PhotoScanFailure('Could not read that image');
  }
  final resized =
      decoded.width > 800 ? img.copyResize(decoded, width: 800) : decoded;
  return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
}

/// AI food photo analysis through the `analyze-food-photo` edge function.
class PhotoScanService {
  PhotoScanService(this._client, this._userId);

  final SupabaseClient _client;
  final String _userId;

  Future<PhotoScanResult> analyze(Uint8List photo, {String? hint}) async {
    final jpeg = await compute(compressForUpload, photo);
    try {
      final res = await _client.functions.invoke(
        'analyze-food-photo',
        body: {
          'imageBase64': base64Encode(jpeg),
          'googleUserId': _userId,
          if (hint != null && hint.trim().isNotEmpty) 'hint': hint.trim(),
        },
      );
      final data = res.data;
      if (data is! Map) {
        throw const PhotoScanFailure('Unexpected response from scan service');
      }
      final map = data.cast<String, dynamic>();
      if (map['error'] != null) {
        if (map['error'] == 'Daily scan limit reached') {
          throw const ScanLimitReached();
        }
        throw PhotoScanFailure('${map['error']}');
      }
      return PhotoScanResult.fromJson(map);
    } on FunctionException catch (e) {
      if (e.status == 429) {
        throw const ScanLimitReached();
      }
      throw PhotoScanFailure('Scan failed (${e.status})');
    }
  }
}
