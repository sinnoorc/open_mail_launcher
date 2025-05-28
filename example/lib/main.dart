import 'package:flutter/material.dart';
import 'package:open_mail_launcher/open_mail_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Open Mail Launcher Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<MailApp> _mailApps = [];
  bool _isLoading = false;
  String _statusMessage = '';

  // Email content controllers
  final _toController = TextEditingController(text: 'example@email.com');
  final _ccController = TextEditingController();
  final _bccController = TextEditingController();
  final _subjectController = TextEditingController(
    text: 'Test Email from Flutter',
  );
  final _bodyController = TextEditingController(
    text:
        'This is a test email sent from the Open Mail Launcher Flutter plugin.',
  );

  @override
  void initState() {
    super.initState();
    _loadMailApps();
  }

  @override
  void dispose() {
    _toController.dispose();
    _ccController.dispose();
    _bccController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadMailApps() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      final apps = await OpenMailLauncher.getMailApps();
      setState(() {
        _mailApps = apps;
        _isLoading = false;
        _statusMessage = 'Found ${apps.length} mail app(s)';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error loading mail apps: $e';
      });
    }
  }

  EmailContent _createEmailContent() {
    return EmailContent(
      to: _toController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      cc: _ccController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      bcc: _bccController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      subject: _subjectController.text,
      body: _bodyController.text,
    );
  }

  Future<void> _openMailApp() async {
    setState(() {
      _statusMessage = 'Opening mail app...';
    });

    try {
      final result = await OpenMailLauncher.openMailApp(
        emailContent: _createEmailContent(),
      );

      if (result.didOpen) {
        setState(() {
          _statusMessage = 'Mail app opened successfully';
        });
      } else if (result.canOpen && result.hasMultipleOptions) {
        // Show picker dialog for iOS or when Android doesn't show native picker
        if (mounted) {
          final selectedApp = await OpenMailLauncher.showMailAppPicker(
            context: context,
            mailApps: result.options,
          );

          if (selectedApp != null) {
            await _openSpecificMailApp(selectedApp);
          } else {
            setState(() {
              _statusMessage = 'No app selected';
            });
          }
        }
      } else {
        setState(() {
          _statusMessage = 'No mail apps available';
        });
        _showNoMailAppsDialog();
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _openSpecificMailApp(MailApp mailApp) async {
    setState(() {
      _statusMessage = 'Opening ${mailApp.name}...';
    });

    try {
      final success = await OpenMailLauncher.openSpecificMailApp(
        mailApp: mailApp,
        emailContent: _createEmailContent(),
      );

      setState(() {
        _statusMessage = success
            ? '${mailApp.name} opened successfully'
            : 'Failed to open ${mailApp.name}';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _composeEmail() async {
    setState(() {
      _statusMessage = 'Composing email...';
    });

    try {
      final success = await OpenMailLauncher.composeEmail(
        emailContent: _createEmailContent(),
      );

      setState(() {
        _statusMessage = success
            ? 'Compose window opened'
            : 'Failed to open compose window';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _checkMailAppAvailable() async {
    try {
      final available = await OpenMailLauncher.isMailAppAvailable();
      setState(() {
        _statusMessage = available
            ? 'Mail app is available'
            : 'No mail app available';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    }
  }

  void _showNoMailAppsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('No Mail Apps'),
          content: const Text(
            'No email applications are installed on this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Open Mail Launcher Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMailApps,
            tooltip: 'Reload mail apps',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      Text(
                        _statusMessage.isEmpty ? 'Ready' : _statusMessage,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Email Composition Form
            Text(
              'Email Content',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _toController,
              decoration: const InputDecoration(
                labelText: 'To (comma separated)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _ccController,
              decoration: const InputDecoration(
                labelText: 'CC (comma separated)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _bccController,
              decoration: const InputDecoration(
                labelText: 'BCC (comma separated)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people_outline),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.subject),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _bodyController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Body',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.message),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Text('Actions', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _openMailApp,
              icon: const Icon(Icons.email),
              label: const Text('Open Mail App'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _composeEmail,
              icon: const Icon(Icons.edit),
              label: const Text('Compose Email'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _checkMailAppAvailable,
              icon: const Icon(Icons.check_circle),
              label: const Text('Check Mail App Available'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 24),

            // Available Mail Apps
            Text(
              'Available Mail Apps',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            if (_mailApps.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('No mail apps found'),
                  subtitle: Text('Tap refresh to reload'),
                ),
              )
            else
              ..._mailApps.map(
                (app) => Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.email,
                      color: app.isDefault ? Colors.blue : null,
                    ),
                    title: Text(app.name),
                    subtitle: Text(app.isDefault ? 'Default app' : app.id),
                    trailing: IconButton(
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => _openSpecificMailApp(app),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
