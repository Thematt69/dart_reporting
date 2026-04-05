import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects common image_picker anti-patterns:
///
/// - Usage of deprecated `ImagePicker.pickImage` static method
///   (should use instance method `ImagePicker().pickImage()`).
/// - Missing error handling for image picking operations.
class ImagePickerRule extends AnalysisRule {
  const ImagePickerRule();

  // Deprecated static method usage
  static final _deprecatedPickImagePattern = RegExp(
    r'ImagePicker\.pickImage\s*\(',
  );

  // Instance pickImage without error handling
  static final _pickImagePattern = RegExp(
    r'\.pickImage\s*\(|\.pickVideo\s*\(|\.pickMultiImage\s*\(',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    if (!source.contains('image_picker') &&
        !source.contains('ImagePicker')) {
      return findings;
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Detect deprecated static method
      if (_deprecatedPickImagePattern.hasMatch(line)) {
        findings.add(Finding(
          ruleId: 'analyzer/image-picker-deprecated-method',
          message:
              'ImagePicker.pickImage() is deprecated. Use '
              'ImagePicker().pickImage(source: ImageSource.camera) '
              'or ImagePicker().pickImage(source: ImageSource.gallery) '
              'instance methods instead.',
          severity: FindingSeverity.warning,
          filePath: filePath,
          line: i + 1,
          helpUri: 'https://pub.dev/packages/image_picker',
        ));
      }

      // Detect pick operations without null check or error handling
      if (_pickImagePattern.hasMatch(line)) {
        final surroundingStart = (i - 3).clamp(0, lines.length - 1);
        final surroundingEnd = (i + 5).clamp(0, lines.length);
        final surroundingLines =
            lines.sublist(surroundingStart, surroundingEnd).join('\n');

        if (!surroundingLines.contains('try') &&
            !surroundingLines.contains('catch') &&
            !surroundingLines.contains('== null') &&
            !surroundingLines.contains('!= null') &&
            !surroundingLines.contains('?.')) {
          findings.add(Finding(
            ruleId: 'analyzer/image-picker-no-null-check',
            message:
                'Image picking operations can return null when the '
                'user cancels. Always check the result for null and '
                'handle errors with try/catch for platform exceptions.',
            severity: FindingSeverity.note,
            filePath: filePath,
            line: i + 1,
          ));
        }
      }
    }

    return findings;
  }
}
