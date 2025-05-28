/// Represents the content for composing an email
class EmailContent {
  /// List of email addresses for the "To" field
  final List<String> to;

  /// List of email addresses for the "CC" field
  final List<String> cc;

  /// List of email addresses for the "BCC" field
  final List<String> bcc;

  /// The email subject
  final String? subject;

  /// The email body content
  final String? body;

  /// Whether the body is HTML formatted
  final bool isHtml;

  /// List of file paths to attach
  final List<String> attachments;

  const EmailContent({
    this.to = const [],
    this.cc = const [],
    this.bcc = const [],
    this.subject,
    this.body,
    this.isHtml = false,
    this.attachments = const [],
  });

  /// Creates an empty EmailContent
  factory EmailContent.empty() => const EmailContent();

  /// Creates EmailContent from a map
  factory EmailContent.fromMap(Map<String, dynamic> map) {
    return EmailContent(
      to: List<String>.from(map['to'] ?? []),
      cc: List<String>.from(map['cc'] ?? []),
      bcc: List<String>.from(map['bcc'] ?? []),
      subject: map['subject'] as String?,
      body: map['body'] as String?,
      isHtml: map['isHtml'] as bool? ?? false,
      attachments: List<String>.from(map['attachments'] ?? []),
    );
  }

  /// Converts this EmailContent to a map
  Map<String, dynamic> toMap() {
    return {
      'to': to,
      'cc': cc,
      'bcc': bcc,
      'subject': subject,
      'body': body,
      'isHtml': isHtml,
      'attachments': attachments,
    };
  }

  /// Creates a copy of this EmailContent with updated fields
  EmailContent copyWith({
    List<String>? to,
    List<String>? cc,
    List<String>? bcc,
    String? subject,
    String? body,
    bool? isHtml,
    List<String>? attachments,
  }) {
    return EmailContent(
      to: to ?? this.to,
      cc: cc ?? this.cc,
      bcc: bcc ?? this.bcc,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      isHtml: isHtml ?? this.isHtml,
      attachments: attachments ?? this.attachments,
    );
  }

  /// Generates a mailto URI from this email content
  String toMailtoUri() {
    final uri = StringBuffer('mailto:');

    // Add recipients
    uri.write(to.join(','));

    final params = <String>[];

    // Add CC
    if (cc.isNotEmpty) {
      params.add('cc=${cc.join(',')}');
    }

    // Add BCC
    if (bcc.isNotEmpty) {
      params.add('bcc=${bcc.join(',')}');
    }

    // Add subject
    if (subject != null && subject!.isNotEmpty) {
      params.add('subject=${Uri.encodeComponent(subject!)}');
    }

    // Add body
    if (body != null && body!.isNotEmpty) {
      params.add('body=${Uri.encodeComponent(body!)}');
    }

    // Append parameters
    if (params.isNotEmpty) {
      uri.write('?${params.join('&')}');
    }

    return uri.toString();
  }

  @override
  String toString() => 'EmailContent(to: $to, subject: $subject)';
}
