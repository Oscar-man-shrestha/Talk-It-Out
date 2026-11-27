import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Downloads a preset picture so it can be uploaded like a picked file.
///
/// Image CDNs often negotiate AVIF, which the backend does not accept
/// (PNG, JPEG, WebP only), so Unsplash URLs are asked for JPEG explicitly.
/// No credentials are sent. Returns null when the image cannot be fetched.
Future<Uint8List?> downloadPresetImage(String url, {Dio? client}) async {
  final dio = client ?? Dio();
  try {
    final uri = Uri.parse(url);
    final target = uri.host == 'images.unsplash.com'
        ? uri.replace(
            queryParameters: {
              for (final entry in uri.queryParameters.entries)
                if (entry.key != 'auto') entry.key: entry.value,
              'fm': 'jpg',
            },
          )
        : uri;
    final response = await dio.getUri<List<int>>(
      target,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    final data = response.data;
    return data == null ? null : Uint8List.fromList(data);
  } catch (_) {
    return null;
  } finally {
    if (client == null) dio.close();
  }
}
