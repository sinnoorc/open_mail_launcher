/// Represents an email application installed on the device
class MailApp {
  /// The display name of the email app
  final String name;

  /// The package name (Android) or URL scheme (iOS) of the email app
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
  String toString() => 'MailApp(name: $name, id: $id, isDefault: $isDefault)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MailApp &&
        other.name == name &&
        other.id == id &&
        other.isDefault == isDefault;
  }

  @override
  int get hashCode => Object.hash(name, id, isDefault);
}
