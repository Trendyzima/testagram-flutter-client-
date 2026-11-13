import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/core/media/media_upload_policy.dart';

void main() {
  group('MediaUploadPolicy', () {
    test('normalizes allowed extensions and rejects unsupported files', () {
      expect(MediaUploadPolicy.normalizeExtension('PHOTO.JPEG', isVideo: false), 'jpeg');
      expect(MediaUploadPolicy.normalizeExtension('clip.WEBM', isVideo: true), 'webm');
      expect(MediaUploadPolicy.normalizeExtension('animated.GIF', isVideo: false), 'gif');
      expect(MediaUploadPolicy.normalizeExtension('photo.AVIF', isVideo: false), 'avif');
      expect(() => MediaUploadPolicy.normalizeExtension('clip.MOV', isVideo: true), throwsFormatException);
      expect(() => MediaUploadPolicy.normalizeExtension('photo.HEIC', isVideo: false), throwsFormatException);
      expect(() => MediaUploadPolicy.normalizeExtension('payload.exe', isVideo: false), throwsFormatException);
      expect(() => MediaUploadPolicy.normalizeExtension('no-extension', isVideo: true), throwsFormatException);
    });
    test('enforces positive size and per-media limits', () {
      expect(() => MediaUploadPolicy.validateSize(0, isVideo: false), throwsFormatException);
      expect(() => MediaUploadPolicy.validateSize(MediaUploadPolicy.imageMaxBytes + 1, isVideo: false), throwsFormatException);
      expect(() => MediaUploadPolicy.validateSize(MediaUploadPolicy.videoMaxBytes + 1, isVideo: true), throwsFormatException);
      expect(() => MediaUploadPolicy.validateSize(MediaUploadPolicy.imageMaxBytes, isVideo: false), returnsNormally);
    });
    test('maps supported extensions to MIME types', () {
      expect(MediaUploadPolicy.contentType('jpg'), 'image/jpeg');
      expect(MediaUploadPolicy.contentType('mp4'), 'video/mp4');
      expect(MediaUploadPolicy.contentType('webm'), 'video/webm');
      expect(MediaUploadPolicy.contentType('gif'), 'image/gif');
      expect(MediaUploadPolicy.contentType('avif'), 'image/avif');
      expect(() => MediaUploadPolicy.contentType('mov'), throwsFormatException);
      expect(() => MediaUploadPolicy.contentType('exe'), throwsFormatException);
    });
  });
}
