import 'package:flutter/foundation.dart';

/// Represents an email application installed on the device
@immutable
class MailApp {
  /// The display name of the email app
  final String name;

  /// Stable identifier for the mail app. Format depends on platform:
  ///
  /// - **Android**: package name (e.g. `com.google.android.gm`).
  /// - **iOS**: URL scheme with trailing `://` (e.g. `googlegmail://`).
  ///   The special id `mailto:` represents the synthesized "Default Mail App"
  ///   entry — opening it routes through the user's iOS-level default mail
  ///   handler (Settings > Default Apps > Mail).
  final String id;

  /// The app icon as base64 encoded string (optional)
  final String? icon;

  /// Whether this is the default email app
  final bool isDefault;

  const MailApp({
    required this.name,
    required this.id,
    this.icon,
    this.isDefault = false,
  });

  /// Creates a MailApp from a platform map
  factory MailApp.fromMap(Map<String, dynamic> map) {
    return MailApp(
      name: map['name'] as String,
      id: map['id'] as String,
      icon: map['icon'] as String?,
      isDefault: map['isDefault'] as bool? ?? false,
    );
  }

  /// Converts this MailApp to a map
  Map<String, dynamic> toMap() {
    return {'name': name, 'id': id, 'icon': icon, 'isDefault': isDefault};
  }

  @override
  String toString() {
    return 'MailApp(name: $name, id: $id, icon: $icon, '
        'isDefault: $isDefault)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MailApp &&
        other.name == name &&
        other.id == id &&
        other.icon == icon &&
        other.isDefault == isDefault;
  }

  @override
  int get hashCode => Object.hash(name, id, icon, isDefault);
}
