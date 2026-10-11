
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BookImage extends StatelessWidget {
  final String source;
  final double? width;
  final double? height;
  final BoxFit fit;

  const BookImage({
    super.key,
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final value = source.trim();

    if (value.startsWith('data:image/')) {
      try {
        final comma = value.indexOf(',');
        final Uint8List bytes =
            base64Decode(value.substring(comma + 1));
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _fallback(),
        );
      } catch (_) {
        return _fallback();
      }
    }

    if (value.isEmpty) return _fallback();

    return Image.network(
      value,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() => Container(
        width: width,
        height: height,
        color: AppTheme.softAccent,
        alignment: Alignment.center,
        child: const Icon(
          Icons.menu_book_outlined,
          size: 30,
          color: AppTheme.accent,
        ),
      );
}
