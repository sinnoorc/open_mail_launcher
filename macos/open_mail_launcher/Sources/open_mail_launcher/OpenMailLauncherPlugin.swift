import Cocoa
import FlutterMacOS

public class OpenMailLauncherPlugin: NSObject, FlutterPlugin {
  private static let mailtoProbe = URL(string: "mailto:")!

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "open_mail_launcher", binaryMessenger: registrar.messenger)
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
      result(defaultMailAppURL() != nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Discovery

  /// Unlike iOS, macOS can enumerate every installed mailto: handler — no
  /// hardcoded scheme list and no LSApplicationQueriesSchemes requirement.
  /// `id` is the app's bundle identifier.
  private func mailAppURLs() -> [URL] {
    if #available(macOS 12.0, *) {
      return NSWorkspace.shared.urlsForApplications(toOpen: Self.mailtoProbe)
    }
    // Deprecated in macOS 12 but the only enumeration API on 10.15–11.
    return (LSCopyApplicationURLsForURL(Self.mailtoProbe as CFURL, .all)?
      .takeRetainedValue() as? [URL]) ?? []
  }

  private func defaultMailAppURL() -> URL? {
    return NSWorkspace.shared.urlForApplication(toOpen: Self.mailtoProbe)
  }

  private func getMailApps() -> [[String: Any]] {
    let defaultURL = defaultMailAppURL()
    // Deduplicate by bundle id: multiple copies of an app (e.g. one in
    // /Applications, one in a DMG cache) enumerate as separate URLs.
    var seen = Set<String>()
    var apps: [[String: Any]] = []
    // List the default first so it survives dedup with its canonical URL.
    let orderedURLs = (defaultURL.map { [$0] } ?? []) + mailAppURLs()

    for url in orderedURLs {
      guard let bundle = Bundle(url: url),
            let bundleId = bundle.bundleIdentifier,
            seen.insert(bundleId).inserted else {
        continue
      }
      apps.append([
        "name": FileManager.default.displayName(atPath: url.path),
        "id": bundleId,
        "icon": pngDataURI(forAppAt: url) ?? NSNull(),
        "isDefault": url == defaultURL
      ])
    }
    return apps
  }

  /// App icon as a base64 PNG data URI — same format as the Android side.
  private func pngDataURI(forAppAt url: URL) -> String? {
    let icon = NSWorkspace.shared.icon(forFile: url.path)
    icon.size = NSSize(width: 64, height: 64)
    guard let tiff = icon.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
      return nil
    }
    return "data:image/png;base64," + png.base64EncodedString()
  }

  // MARK: - Launching

  private func openMailApp(emailContent: [String: Any]?, result: @escaping FlutterResult) {
    let mailApps = getMailApps()

    guard let defaultURL = defaultMailAppURL(), !mailApps.isEmpty else {
      result(["didOpen": false, "canOpen": false, "options": []])
      return
    }

    // macOS always has an authoritative system default mailto: handler, so
    // open it directly instead of returning options — mirrors Android's
    // default-first behavior, and matches what clicking a mailto: link does.
    let reply: (Bool) -> Void = { didOpen in
      DispatchQueue.main.async {
        result(["didOpen": didOpen, "canOpen": true, "options": mailApps])
      }
    }

    if let mailtoURL = createMailtoURL(from: emailContent) {
      reply(NSWorkspace.shared.open(mailtoURL))
    } else {
      // No content → open the default mail app itself (inbox), not compose.
      NSWorkspace.shared.openApplication(at: defaultURL, configuration: .init()) { app, _ in
        reply(app != nil)
      }
    }
  }

  private func openSpecificMailApp(appId: String, emailContent: [String: Any]?, result: @escaping FlutterResult) {
    guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appId) else {
      result(false)
      return
    }

    let reply: (Bool) -> Void = { success in
      DispatchQueue.main.async { result(success) }
    }

    if let mailtoURL = createMailtoURL(from: emailContent) {
      NSWorkspace.shared.open([mailtoURL], withApplicationAt: appURL, configuration: .init()) { app, _ in
        reply(app != nil)
      }
    } else {
      // No content → open the app's main window (inbox), not compose.
      NSWorkspace.shared.openApplication(at: appURL, configuration: .init()) { app, _ in
        reply(app != nil)
      }
    }
  }

  private func composeEmail(emailContent: [String: Any], result: @escaping FlutterResult) {
    guard let mailtoURL = createMailtoURL(from: emailContent) else {
      result(false)
      return
    }
    result(NSWorkspace.shared.open(mailtoURL))
  }

  // MARK: - mailto: building (mirrors the iOS implementation)

  /// Returns nil for nil content — "open the app", not "compose".
  private func createMailtoURL(from emailContent: [String: Any]?) -> URL? {
    guard emailContent != nil else { return nil }
    let to = stringList("to", from: emailContent)
    return createURL(
      base: "mailto:\(to.joined(separator: ","))",
      queryItems: queryItems(from: emailContent)
    )
  }

  private func createURL(base: String, queryItems: [URLQueryItem]) -> URL? {
    guard var components = URLComponents(string: base) else {
      return URL(string: base)
    }
    components.queryItems = queryItems.isEmpty ? nil : queryItems
    return components.url
  }

  private func queryItems(from emailContent: [String: Any]?) -> [URLQueryItem] {
    var items: [URLQueryItem] = []

    appendJoinedQueryItem(to: &items, name: "cc", values: stringList("cc", from: emailContent))
    appendJoinedQueryItem(to: &items, name: "bcc", values: stringList("bcc", from: emailContent))

    if let subject = stringValue("subject", from: emailContent) {
      items.append(URLQueryItem(name: "subject", value: subject))
    }
    if let body = stringValue("body", from: emailContent) {
      items.append(URLQueryItem(name: "body", value: body))
    }
    return items
  }

  private func appendJoinedQueryItem(to items: inout [URLQueryItem], name: String, values: [String]) {
    if !values.isEmpty {
      items.append(URLQueryItem(name: name, value: values.joined(separator: ",")))
    }
  }

  private func stringList(_ key: String, from emailContent: [String: Any]?) -> [String] {
    guard let values = emailContent?[key] as? [String] else { return [] }
    return values.filter { !$0.isEmpty }
  }

  private func stringValue(_ key: String, from emailContent: [String: Any]?) -> String? {
    guard let value = emailContent?[key] as? String, !value.isEmpty else { return nil }
    return value
  }
}
