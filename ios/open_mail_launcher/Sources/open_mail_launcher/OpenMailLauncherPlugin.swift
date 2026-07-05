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
        "icon": NSNull(),
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
          "icon": NSNull(),
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
    let to = stringList("to", from: emailContent)
    return createURL(
      base: "mailto:\(to.joined(separator: ","))",
      queryItems: queryItems(from: emailContent, includeTo: false)
    )
  }
  
  private func createAppSpecificURL(scheme: String, emailContent: [String: Any]?) -> URL? {
    // First-class compose URL builders for apps with documented URL schemes.
    //
    // For everything else we fall back to substituting `mailto:` with the
    // app's scheme. This works for some apps and silently drops compose
    // params for others — adding explicit builders requires verifying the
    // app's URL format on a real device. ProtonMail / Fastmail / Airmail
    // builders are TODO pending empirical verification (v0.3).

    // No content means "open the mail app", not "compose an email" — open
    // the app's bare scheme (inbox / main screen) instead of a compose URL.
    // The synthesized "Default Mail App" entry (mailto:) is the exception:
    // iOS has no "open default mail app" API, so it still composes.
    if emailContent == nil, scheme != "mailto:" {
      return URL(string: scheme)
    }

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
    return createURL(
      base: "ymail://mail/compose",
      queryItems: queryItems(from: emailContent)
    )
  }
  
  private func createGmailURL(emailContent: [String: Any]?) -> URL? {
    return createURL(
      base: "googlegmail:///co",
      queryItems: queryItems(from: emailContent)
    )
  }
  
  private func createOutlookURL(emailContent: [String: Any]?) -> URL? {
    return createURL(
      base: "ms-outlook://compose",
      queryItems: queryItems(from: emailContent)
    )
  }
  
  private func createSparkURL(emailContent: [String: Any]?) -> URL? {
    return createURL(
      base: "readdle-spark://compose",
      queryItems: queryItems(
        from: emailContent,
        toKey: "recipient",
        includeCcBcc: false
      )
    )
  }

  private func createURL(base: String, queryItems: [URLQueryItem]) -> URL? {
    guard var components = URLComponents(string: base) else {
      return URL(string: base)
    }

    components.queryItems = queryItems.isEmpty ? nil : queryItems
    return components.url
  }

  private func queryItems(
    from emailContent: [String: Any]?,
    toKey: String = "to",
    includeTo: Bool = true,
    includeCcBcc: Bool = true
  ) -> [URLQueryItem] {
    var items: [URLQueryItem] = []

    appendJoinedQueryItem(
      to: &items,
      name: toKey,
      values: includeTo ? stringList("to", from: emailContent) : []
    )

    if includeCcBcc {
      appendJoinedQueryItem(
        to: &items,
        name: "cc",
        values: stringList("cc", from: emailContent)
      )
      appendJoinedQueryItem(
        to: &items,
        name: "bcc",
        values: stringList("bcc", from: emailContent)
      )
    }

    if let subject = stringValue("subject", from: emailContent) {
      items.append(URLQueryItem(name: "subject", value: subject))
    }

    if let body = stringValue("body", from: emailContent) {
      items.append(URLQueryItem(name: "body", value: body))
    }

    return items
  }

  private func appendJoinedQueryItem(
    to items: inout [URLQueryItem],
    name: String,
    values: [String]
  ) {
    if !values.isEmpty {
      items.append(
        URLQueryItem(name: name, value: values.joined(separator: ","))
      )
    }
  }

  private func stringList(_ key: String, from emailContent: [String: Any]?) -> [String] {
    guard let values = emailContent?[key] as? [String] else {
      return []
    }
    return values.filter { !$0.isEmpty }
  }

  private func stringValue(_ key: String, from emailContent: [String: Any]?) -> String? {
    guard let value = emailContent?[key] as? String, !value.isEmpty else {
      return nil
    }
    return value
  }
}
