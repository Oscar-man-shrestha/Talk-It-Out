import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/core/utils/image_picker_helper.dart';

/// Largest image the server accepts (API.md 49).
const maxChatImageBytes = 5 * 1024 * 1024;

/// A photo chosen in the composer, not yet uploaded.
typedef PickedImage = ({Uint8List bytes, String filename});

/// Opens the system picker. Returns null when cancelled; throws a
/// [RepositoryException] with a readable message for a bad file.
Future<PickedImage?> pickChatImage() async {
  final dataUrl = await pickImageFile();
  if (dataUrl == null) return null;
  final comma = dataUrl.indexOf(',');
  final header = comma > 0 ? dataUrl.substring(0, comma) : '';
  if (comma < 0 || !header.contains('base64')) {
    throw const RepositoryException(
      code: 'validation',
      message: AppStrings.imageUnreadable,
    );
  }
  final bytes = base64Decode(dataUrl.substring(comma + 1));
  if (bytes.length > maxChatImageBytes) {
    throw const RepositoryException(
      code: 'file_too_large',
      message: 'Images must be 5 MB or smaller.',
    );
  }
  final ext = header.contains('png')
      ? 'png'
      : header.contains('webp')
      ? 'webp'
      : 'jpg';
  return (bytes: bytes, filename: 'photo.$ext');
}

typedef AttachmentKey = ({String groupId, String attachmentId});

/// Image bytes, fetched with the signed-in session (the server only
/// serves an image to people allowed to see its message).
final attachmentBytesProvider = FutureProvider.family<Uint8List, AttachmentKey>(
  (ref, key) {
    return ref
        .watch(groupRepositoryProvider)
        .fetchAttachment(key.groupId, key.attachmentId);
  },
);

/// An image inside a chat bubble or review card. Tap to view full size.
class ChatImage extends ConsumerWidget {
  const ChatImage({
    required this.groupId,
    required this.attachmentId,
    this.maxHeight = 260,
    super.key,
  });

  final String groupId;
  final String attachmentId;
  final double maxHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(
      attachmentBytesProvider((groupId: groupId, attachmentId: attachmentId)),
    );
    final radius = BorderRadius.circular(10);
    return ClipRRect(
      key: ValueKey('chat-image-$attachmentId'),
      borderRadius: radius,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight, minWidth: 120),
        child: image.when(
          data: (bytes) => GestureDetector(
            onTap: () => _openViewer(context, bytes),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const _ImagePlaceholder(),
            ),
          ),
          loading: () => const SizedBox(
            height: 160,
            child: ColoredBox(
              color: Brand.muted,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
          error: (_, _) => const _ImagePlaceholder(),
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, Uint8List bytes) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(child: Image.memory(bytes)),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filled(
                tooltip: 'Close',
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 80,
      child: ColoredBox(
        color: Brand.muted,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, size: 16, color: Brand.inkSoft),
              SizedBox(width: 6),
              Text(
                AppStrings.imageUnavailable,
                style: TextStyle(fontSize: 12, color: Brand.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The chosen photo above the message box, with what happens to it.
class PendingImagePreview extends StatelessWidget {
  const PendingImagePreview({
    required this.image,
    required this.anonymous,
    required this.onRemove,
    super.key,
  });

  final PickedImage image;
  final bool anonymous;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('pending-image'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Brand.accentSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Brand.accentBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              image.bytes,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                width: 56,
                height: 56,
                child: Icon(Icons.image_outlined, color: Brand.inkSoft),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Photo ready to send',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Brand.accentInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  anonymous
                      ? AppStrings.imagePrivacyAnonymous
                      : AppStrings.imagePrivacyNamed,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: Brand.accentInk,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('remove-pending-image'),
            tooltip: AppStrings.removeImage,
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18, color: Brand.accentInk),
          ),
        ],
      ),
    );
  }
}
