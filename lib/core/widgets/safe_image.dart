import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class SafeImage extends StatelessWidget {
  const SafeImage({
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.fallbackIcon = Icons.image_outlined,
    this.fallbackColor,
    super.key,
  });

  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final IconData fallbackIcon;
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return _buildFallback();
    }

    if (url.startsWith('data:')) {
      try {
        final commaIndex = url.indexOf(',');
        if (commaIndex != -1) {
          final base64String = url.substring(commaIndex + 1);
          final Uint8List bytes = base64Decode(base64String);
          return Image.memory(
            bytes,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (ctx, err, stack) => _buildFallback(),
          );
        }
      } catch (_) {
        return _buildFallback();
      }
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (ctx, err, stack) => _buildFallback(),
      );
    }

    return _buildFallback();
  }

  Widget _buildFallback() {
    return Container(
      width: width,
      height: height,
      color: fallbackColor ?? const Color(0xFFE4E4E7),
      child: Center(
        child: Icon(
          fallbackIcon,
          size: (width != null && width! < 40) ? 18 : 28,
          color: const Color(0xFF71717A),
        ),
      ),
    );
  }
}
