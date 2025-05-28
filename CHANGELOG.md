## 0.0.1

### Initial Release

* **Email App Discovery**: Query for available email applications on both Android and iOS
* **Smart App Opening**: Automatically handle single vs multiple email apps with native choosers
* **Email Composition**: Pre-fill emails with recipients (To, CC, BCC), subject, and body content
* **Cross-Platform Support**: Full Android and iOS implementation with platform-specific optimizations
* **Modern Architecture**: Platform interface pattern with proper error handling and data models
* **Attachment Support**: File attachments on Android platform
* **Built-in UI**: Mail app picker dialog for multiple app selection
* **Comprehensive API**: 
  - `getMailApps()` - Get list of available email apps
  - `openMailApp()` - Open email app with smart handling
  - `openSpecificMailApp()` - Open a specific email application
  - `composeEmail()` - Compose email with pre-filled content
  - `isMailAppAvailable()` - Check if any email app is available
  - `showMailAppPicker()` - Show picker dialog for app selection

### Platform Features

**Android:**
- Uses PackageManager for email app discovery
- Supports Intent.ACTION_SENDTO and Intent.ACTION_SEND_MULTIPLE
- Automatic email intent queries for Android 11+ compatibility
- App icon extraction as base64 encoded strings
- Default email app detection
- File attachment support

**iOS:**
- URL scheme-based app detection for known email applications
- Support for popular email apps (Gmail, Outlook, Spark, etc.)
- Custom URL generation for different email clients
- Fallback to default Mail app
- Proper URL encoding for email content

### Models
- `MailApp` - Represents email applications with name, ID, icon, and default status
- `EmailContent` - Comprehensive email data model with mailto URI generation
- `OpenMailAppResult` - Result wrapper for app opening operations with success/error states

### Development
- Comprehensive test coverage with unit tests and mock implementations
- Example app demonstrating all features
- Complete documentation with usage examples
- Flutter 3.3.0+ compatibility
- Modern Dart null safety support
