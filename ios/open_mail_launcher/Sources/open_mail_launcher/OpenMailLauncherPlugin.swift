import Flutter
import UIKit
import MessageUI

public class OpenMailLauncherPlugin: NSObject, FlutterPlugin {
  private static let knownMailApps: [(name: String, scheme: String)] = [
    ("Mail", "message://"),
    ("Gmail", "googlegmail://"),
    ("Outlook", "ms-outlook://"),
    ("Yahoo Mail", "ymail://"),
    ("Spark", "readdle-spark://"),
    ("Airmail", "airmail://"),
    ("Dispatch", "x-dispatch://"),
    ("Fastmail", "fastmail://"),
    ("Superhuman", "superhuman://"),
    ("ProtonMail", "protonmail://"),
    ("Hey", "hey://"),
    ("Canary Mail", "canarymail://"),
    ("Spike", "spike://"),
    ("Newton", "newton://"),
    ("Polymail", "polymail://"),
    ("TypeApp", "typeapp://"),
    ("BlueMail", "bluemail://"),
    ("Edison Mail", "edison://"),
    ("Twobird", "twobird://")
  ]
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "open_mail_launcher", binaryMessenger: registrar.messenger())
    let instance = OpenMailLauncherPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getMailApps":
      result(getMailApps())
    case "openMailApp":
      let emailContent = call.arguments as? [String: Any]
      openMailApp(emailContent: emailContent, result: result)
    case "openSpecificMailApp":
      if let args = call.arguments as? [String: Any],
         let appId = args["appId"] as? String {
        openSpecificMailApp(appId: appId, emailContent: args, result: result)
      } else {
        result(false)
      }
    case "composeEmail":
      let emailContent = call.arguments as? [String: Any] ?? [:]
      composeEmail(emailContent: emailContent, result: result)
    case "isMailAppAvailable":
      result(isMailAppAvailable())
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func getMailApps() -> [[String: Any]] {
    var availableApps: [[String: Any]] = []
    
    // Always include default Mail app
    availableApps.append([
      "name": "Mail",
      "id": "mailto:",
      "icon": nil,
      "isDefault": true
    ])
    
    // Check for other known mail apps
    for app in OpenMailLauncherPlugin.knownMailApps {
      if let url = URL(string: app.scheme),
         UIApplication.shared.canOpenURL(url) {
        availableApps.append([
          "name": app.name,
          "id": app.scheme,
          "icon": nil,
          "isDefault": false
        ])
      }
    }
    
    return availableApps
  }
  
  private func openMailApp(emailContent: [String: Any]?, result: @escaping FlutterResult) {
    let mailApps = getMailApps()
    
    if mailApps.isEmpty {
      result([
        "didOpen": false,
        "canOpen": false,
        "options": []
      ])
      return
    }
    
    // On iOS, we can't show a native picker, so we return the available options
    if mailApps.count > 1 {
      result([
        "didOpen": false,
        "canOpen": true,
        "options": mailApps
      ])
      return
    }
    
    // If only one app (default Mail), open it
    if let mailtoUrl = createMailtoURL(from: emailContent) {
      if UIApplication.shared.canOpenURL(mailtoUrl) {
        UIApplication.shared.open(mailtoUrl) { success in
          result([
            "didOpen": success,
            "canOpen": true,
            "options": mailApps
          ])
        }
      } else {
        result([
          "didOpen": false,
          "canOpen": false,
          "options": []
        ])
      }
    } else {
      result([
        "didOpen": false,
        "canOpen": false,
        "options": []
      ])
    }
  }
  
  private func openSpecificMailApp(appId: String, emailContent: [String: Any]?, result: @escaping FlutterResult) {
    if appId == "mailto:" {
      // Default mail app
      if let mailtoUrl = createMailtoURL(from: emailContent) {
        UIApplication.shared.open(mailtoUrl) { success in
          result(success)
        }
      } else {
        result(false)
      }
    } else {
      // Third-party mail app
      if let appUrl = createAppSpecificURL(scheme: appId, emailContent: emailContent) {
        UIApplication.shared.open(appUrl) { success in
          result(success)
        }
      } else {
        result(false)
      }
    }
  }
  
  private func composeEmail(emailContent: [String: Any], result: @escaping FlutterResult) {
    if let mailtoUrl = createMailtoURL(from: emailContent) {
      UIApplication.shared.open(mailtoUrl) { success in
        result(success)
      }
    } else {
      result(false)
    }
  }
  
  private func isMailAppAvailable() -> Bool {
    if let url = URL(string: "mailto:") {
      return UIApplication.shared.canOpenURL(url)
    }
    return false
  }
  
  private func createMailtoURL(from emailContent: [String: Any]?) -> URL? {
    var urlString = "mailto:"
    
    guard let emailContent = emailContent else {
      return URL(string: urlString)
    }
    
    // Add recipients
    if let to = emailContent["to"] as? [String] {
      urlString += to.joined(separator: ",")
    }
    
    var params: [String] = []
    
    // Add CC
    if let cc = emailContent["cc"] as? [String], !cc.isEmpty {
      params.append("cc=\(cc.joined(separator: ","))")
    }
    
    // Add BCC
    if let bcc = emailContent["bcc"] as? [String], !bcc.isEmpty {
      params.append("bcc=\(bcc.joined(separator: ","))")
    }
    
    // Add subject
    if let subject = emailContent["subject"] as? String,
       let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
      params.append("subject=\(encodedSubject)")
    }
    
    // Add body
    if let body = emailContent["body"] as? String,
       let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
      params.append("body=\(encodedBody)")
    }
    
    // Append parameters
    if !params.isEmpty {
      urlString += "?" + params.joined(separator: "&")
    }
    
    return URL(string: urlString)
  }
  
  private func createAppSpecificURL(scheme: String, emailContent: [String: Any]?) -> URL? {
    // Different mail apps have different URL schemes
    // This is a simplified version - each app may have its own format
    
    if scheme.contains("gmail") {
      return createGmailURL(emailContent: emailContent)
    } else if scheme.contains("outlook") {
      return createOutlookURL(emailContent: emailContent)
    } else if scheme.contains("spark") {
      return createSparkURL(emailContent: emailContent)
    } else {
      // For other apps, try the mailto approach with their scheme
      if var urlString = createMailtoURL(from: emailContent)?.absoluteString {
        urlString = urlString.replacingOccurrences(of: "mailto:", with: scheme)
        return URL(string: urlString)
      }
    }
    
    return URL(string: scheme)
  }
  
  private func createGmailURL(emailContent: [String: Any]?) -> URL? {
    var urlString = "googlegmail://co"
    var params: [String] = []
    
    if let emailContent = emailContent {
      if let to = emailContent["to"] as? [String], !to.isEmpty {
        params.append("to=\(to.joined(separator: ","))")
      }
      
      if let cc = emailContent["cc"] as? [String], !cc.isEmpty {
        params.append("cc=\(cc.joined(separator: ","))")
      }
      
      if let bcc = emailContent["bcc"] as? [String], !bcc.isEmpty {
        params.append("bcc=\(bcc.joined(separator: ","))")
      }
      
      if let subject = emailContent["subject"] as? String,
         let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
        params.append("subject=\(encodedSubject)")
      }
      
      if let body = emailContent["body"] as? String,
         let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
        params.append("body=\(encodedBody)")
      }
    }
    
    if !params.isEmpty {
      urlString += "?" + params.joined(separator: "&")
    }
    
    return URL(string: urlString)
  }
  
  private func createOutlookURL(emailContent: [String: Any]?) -> URL? {
    var urlString = "ms-outlook://compose"
    var params: [String] = []
    
    if let emailContent = emailContent {
      if let to = emailContent["to"] as? [String], !to.isEmpty {
        params.append("to=\(to.joined(separator: ","))")
      }
      
      if let cc = emailContent["cc"] as? [String], !cc.isEmpty {
        params.append("cc=\(cc.joined(separator: ","))")
      }
      
      if let bcc = emailContent["bcc"] as? [String], !bcc.isEmpty {
        params.append("bcc=\(bcc.joined(separator: ","))")
      }
      
      if let subject = emailContent["subject"] as? String,
         let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
        params.append("subject=\(encodedSubject)")
      }
      
      if let body = emailContent["body"] as? String,
         let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
        params.append("body=\(encodedBody)")
      }
    }
    
    if !params.isEmpty {
      urlString += "?" + params.joined(separator: "&")
    }
    
    return URL(string: urlString)
  }
  
  private func createSparkURL(emailContent: [String: Any]?) -> URL? {
    // Spark uses a similar format to mailto
    if let mailtoUrl = createMailtoURL(from: emailContent) {
      let sparkUrl = mailtoUrl.absoluteString.replacingOccurrences(of: "mailto:", with: "readdle-spark://compose?recipient=")
      return URL(string: sparkUrl)
    }
    return URL(string: "readdle-spark://")
  }
}
