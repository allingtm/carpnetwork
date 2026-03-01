import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/photos/photo_database.dart';
import '../theme/app_theme.dart';

const _maxPhotos = 5;

class PhotoCaptureWidget extends StatefulWidget {
  final String? catchReportId;
  final String groupId;
  final List<String> photoPaths;
  final ValueChanged<List<String>> onPhotosChanged;

  const PhotoCaptureWidget({
    super.key,
    required this.catchReportId,
    required this.groupId,
    required this.photoPaths,
    required this.onPhotosChanged,
  });

  @override
  State<PhotoCaptureWidget> createState() => _PhotoCaptureWidgetState();
}

class _PhotoCaptureWidgetState extends State<PhotoCaptureWidget> {
  final _picker = ImagePicker();
  bool _processing = false;

  Future<void> _capturePhoto(ImageSource source) async {
    if (widget.photoPaths.length >= _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 photos per catch')),
      );
      return;
    }

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 4096, // Let isolate handle the actual resize
    );
    if (picked == null) return;

    setState(() => _processing = true);

    try {
      final rawBytes = await picked.readAsBytes();

      // Resize on a separate isolate to avoid UI jank
      final resizedBytes = await Isolate.run(() {
        final image = img.decodeImage(rawBytes);
        if (image == null) return rawBytes;
        final resized = img.copyResize(image, width: 2048);
        return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
      });

      // Save to temp directory
      final tempDir = await getTemporaryDirectory();
      final fileId = const Uuid().v4();
      final filePath = '${tempDir.path}/catch_photo_$fileId.jpg';
      await File(filePath).writeAsBytes(resizedBytes);

      // Create PendingUpload record if we have a catch report ID
      if (widget.catchReportId != null) {
        final db = PhotoDatabase();
        await db.insertUpload(
          PendingUploadsCompanion(
            id: Value(fileId),
            catchReportId: Value(widget.catchReportId!),
            groupId: Value(widget.groupId),
            localFilePath: Value(filePath),
            status: const Value('pending'),
          ),
        );
      }

      final updated = [...widget.photoPaths, filePath];
      widget.onPhotosChanged(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process photo: $e'),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _removePhoto(int index) {
    final updated = [...widget.photoPaths];
    final removed = updated.removeAt(index);
    widget.onPhotosChanged(updated);
    // Clean up temp file
    try { File(removed).delete(); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Photo thumbnails
        if (widget.photoPaths.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.photoPaths.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(widget.photoPaths[index]),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removePhoto(index),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Pending upload indicator
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Pending upload',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        const SizedBox(height: 8),

        // Capture buttons
        if (_processing)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.photoPaths.length >= _maxPhotos
                      ? null
                      : () => _capturePhoto(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.photoPaths.length >= _maxPhotos
                      ? null
                      : () => _capturePhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),

        Text(
          '${widget.photoPaths.length}/$_maxPhotos photos',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
