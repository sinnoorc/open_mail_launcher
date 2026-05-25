import Flutter
import UIKit

public class OpenMailLauncherPlugin: NSObject, FlutterPlugin {
  // Apps probed via canOpenURL. Each entry requires its scheme to be
  // listed in the consuming app's Info.plist LSApplicationQueriesSchemes;
  // schemes absent from the consumer's plist silently return false.
  //
  // Removed in v0.2.0 (audit C-3): Newton (shutdown 2024), Twobird (shutdown 2022),
  // Dispatch (no updates since ~2016), TypeApp (alias of BlueMail).
  private static let knownMailApps: [(name: String, scheme: String)] = [
    ("Mail", "message://"),
    ("Gmail", "googlegmail://"),
    ("Outlook", "ms-outlook://"),
    ("Yahoo Mail", "ymail://"),
    ("Spark", "readdle-spark://"),
    ("Airmail", "airmail://"),
    ("Fastmail", "fastmail://"),
    ("Superhuman", "superhuman://"),
    ("ProtonMail", "protonmail://"),
    ("Hey", "hey://"),
    ("Canary Mail", "canarymail://"),
    ("Spike", "spike://"),
    ("Polymail", "polymail://"),
    ("BlueMail", "bluemail://"),
    ("Edison Mail", "edison://")
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
        let emailContent = args["emailContent"] as? [String: Any]
        openSpecificMailApp(appId: appId, emailContent: emailContent, result: result)
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

    // Prepend the synthesized "Default Mail App" entry: id="mailto:"
    // routes through UIApplication.open which the system delivers to
    // the user's chosen default mail handler (iOS 14+ Settings > Default
    // Apps > Mail). Always available when any app on the device handles
    // mailto — which is the case whenever any mail app is installed.
    //
    // Marked isDefault=true; on iOS this is the only entry whose
    // identity reflects user preference. Apple Mail (message://) below
    // is marked isDefault=false: it's the OS-bundled mail app, but if
    // the user has set Gmail (or anything else) as the default mailto
    // handler then Apple Mail is no longer "the default" in any
    // meaningful sense.
    if let mailtoUrl = URL(string: "mailto:"),
       UIApplication.shared.canOpenURL(mailtoUrl) {
      availableApps.append([
        "name": "Default Mail App",
        "id": "mailto:",
        "icon": nil as String?,
        "isDefault": true
      ])
    }

    // Probe each known scheme. Apps whose schemes are absent from the
    // consumer's Info.plist LSApplicationQueriesSchemes silently return
    // false here (iOS privacy enforcement).
    for app in OpenMailLauncherPlugin.knownMailApps {
      if let url = URL(string: app.scheme),
         UIApplication.shared.canOpenURL(url) {
        availableApps.append([
          "name": app.name,
          "id": app.scheme,
          "icon": nil as String?,
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

    // Single app — open via its specific scheme.
    guard let appId = mailApps[0]["id"] as? String,
          let appUrl = createAppSpecificURL(scheme: appId, emailContent: emailContent),
          UIApplication.shared.canOpenURL(appUrl) else {
      result([
        "didOpen": false,
        "canOpen": false,
        "options": []
      ])
      return
    }

    UIApplication.shared.open(appUrl) { success in
      result([
        "didOpen": success,
        "canOpen": true,
        "options": mailApps
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
    // First-class compose URL builders for apps with documented URL schemes.
    //
    // For everything else we fall back to substituting `mailto:` with the
    // app's scheme. This works for some apps and silently drops compose
    // params for others — adding explicit builders requires verifying the
    // app's URL format on a real device. ProtonMail / Fastmail / Airmail
    // builders are TODO pending empirical verification (v0.3).

    // The synthesized "Default Mail App" entry uses mailto: directly,
    // delegating routing to the user's iOS default handler.
    if scheme == "mailto:" {
      return createMailtoURL(from: emailContent)
    }

    // Apple Mail is detected via `message://` but composes via `mailto:`
    // (the `message://` scheme is for opening specific messages, not
    // compose). Route accordingly.
    if scheme == "message://" {
      return createMailtoURL(from: emailContent)
    }

    if scheme.contains("gmail") {
      return createGmailURL(emailContent: emailContent)
    } else if scheme.contains("outlook") {
      return createOutlookURL(emailContent: emailContent)
    } else if scheme.contains("spark") {
      return createSparkURL(emailContent: emailContent)
    } else if scheme == "ymail://" {
      return createYahooURL(emailContent: emailContent)
    } else {
      if var urlString = createMailtoURL(from: emailContent)?.absoluteString {
        urlString = urlString.replacingOccurrences(of: "mailto:", with: scheme)
        return URL(string: urlString)
      }
    }

    return URL(string: scheme)
  }

  private func createYahooURL(emailContent: [String: Any]?) -> URL? {
    // Yahoo Mail iOS app accepts compose params under the `ymail://mail/compose`
    // path with `to`, `cc`, `bcc`, `subject`, `body` keys.
    var urlString = "ymail://mail/compose"
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
