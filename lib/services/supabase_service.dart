
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const url = 'https://uvawvvrytmkizehgvfky.supabase.co';
  static const anonKey = 'sb_publishable_ISrxDSVQCo4Bw7DBxPIcuw_TCCNrrDC';

  static Future<void> init() async {
    if (anonKey.contains('PASTE_')) return;
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  static bool get configured => !anonKey.contains('PASTE_');

  static Future<String> uploadBookCover({
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (!configured) {
      throw StateError('Supabase Storage is not configured.');
    }

    final client = Supabase.instance.client;
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = 'books/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final lower = safeName.toLowerCase();
    final contentType = lower.endsWith('.png')
        ? 'image/png'
        : lower.endsWith('.webp')
            ? 'image/webp'
            : lower.endsWith('.gif')
                ? 'image/gif'
                : 'image/jpeg';

    try {
      await client.storage.from('athenaeum_bookstore').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          upsert: false,
          contentType: contentType,
        ),
      );
      return client.storage.from('athenaeum_bookstore').getPublicUrl(path);
    } on StorageException catch (e) {
      throw StateError(
        'Image upload failed: ${e.message}. Check the Supabase '
        'athenaeum_bookstore bucket and its upload policy.',
      );
    } catch (e) {
      throw StateError('Image upload failed: $e');
    }
  }
}
