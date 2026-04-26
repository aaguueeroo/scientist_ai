import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../../../models/project.dart';

/// Outcome of a `pickAttachment` call. Wraps either a successfully picked
/// attachment, the user cancelling, or an error so callers can render the
/// appropriate UI without a try/catch leaking up to the widget tree.
sealed class PickAttachmentResult {
  const PickAttachmentResult();
}

class PickedAttachment extends PickAttachmentResult {
  const PickedAttachment(this.attachment);
  final ProjectAttachment attachment;
}

class PickCancelled extends PickAttachmentResult {
  const PickCancelled();
}

class PickFailed extends PickAttachmentResult {
  const PickFailed(this.message);
  final String message;
}

/// Thin, testable wrapper over `FilePicker.platform.pickFiles` that
/// converts the platform result into a [ProjectAttachment]. All errors
/// are caught, logged via [debugPrint], and surfaced as [PickFailed] so
/// the UI never receives an unhandled exception (per app error policy).
class ProjectFilePicker {
  const ProjectFilePicker();

  Future<PickAttachmentResult> pickAttachment() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: false,
        withReadStream: false,
      );
      if (result == null || result.files.isEmpty) {
        return const PickCancelled();
      }
      final PlatformFile file = result.files.first;
      return PickedAttachment(
        ProjectAttachment(
          fileName: file.name,
          sizeBytes: file.size,
          addedAt: DateTime.now(),
        ),
      );
    } catch (err, stackTrace) {
      debugPrint('ProjectFilePicker error: $err\n$stackTrace');
      return const PickFailed(
        'Could not open the file picker. Please try again.',
      );
    }
  }
}
