import 'mail_app.dart';

/// Result of attempting to open a mail app
class OpenMailAppResult {
  /// Whether a mail app was successfully opened
  final bool didOpen;

  /// Whether there are mail apps available that can be opened
  final bool canOpen;

  /// List of available mail apps (if any)
  final List<MailApp> options;

  /// Error message if something went wrong
  final String? error;

  const OpenMailAppResult({
    required this.didOpen,
    required this.canOpen,
    this.options = const [],
    this.error,
  });

  /// Creates a successful result
  factory OpenMailAppResult.success({List<MailApp> options = const []}) {
    return OpenMailAppResult(didOpen: true, canOpen: true, options: options);
  }

  /// Creates a result indicating multiple apps are available
  factory OpenMailAppResult.multiple({required List<MailApp> options}) {
    return OpenMailAppResult(didOpen: false, canOpen: true, options: options);
  }

  /// Creates a result indicating no mail apps are available
  factory OpenMailAppResult.noApps() {
    return const OpenMailAppResult(didOpen: false, canOpen: false, options: []);
  }

  /// Creates an error result
  factory OpenMailAppResult.error(String message) {
    return OpenMailAppResult(didOpen: false, canOpen: false, error: message);
  }

  /// Whether the result represents a successful operation
  bool get isSuccess => didOpen || (canOpen && options.isNotEmpty);

  /// Whether there are multiple mail apps to choose from
  bool get hasMultipleOptions => !didOpen && canOpen && options.length > 1;

  @override
  String toString() {
    return 'OpenMailAppResult(didOpen: $didOpen, canOpen: $canOpen, '
        'options: ${options.length}, error: $error)';
  }
}
