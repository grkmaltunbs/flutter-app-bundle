import Flutter
import UIKit
import UserNotifications
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var actionChannel: FlutterMethodChannel?
  private var pendingActions: [[String: Any]] = []
  private var actionsReady = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    UNUserNotificationCenter.current().delegate = self
    // Foreground actions restore the signed-in relay before writing an answer.
    let allow = UNNotificationAction(identifier: "allow", title: "Allow", options: [.foreground])
    let deny = UNNotificationAction(identifier: "deny", title: "Deny", options: [.foreground, .destructive])
    let approve = UNNotificationAction(identifier: "allow", title: "Approve", options: [.foreground])
    UNUserNotificationCenter.current().setNotificationCategories([
      UNNotificationCategory(identifier: "kit.permission", actions: [allow, deny], intentIdentifiers: []),
      UNNotificationCategory(identifier: "kit.plan", actions: [approve], intentIdentifiers: [])
    ])
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "KatyaNotificationActions") else { return }
    let channel = FlutterMethodChannel(name: "dev.flutterkit.kitApp/notification_actions", binaryMessenger: registrar.messenger())
    actionChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "ready":
        self.actionsReady = true
        result(self.pendingActions)
      case "withdraw":
        if let requestId = call.arguments as? String {
          self.withdraw(requestId: requestId) { result(nil) }
        } else {
          result(nil)
        }
      case "handled":
        if let id = call.arguments as? String {
          self.pendingActions.removeAll { ($0["notificationId"] as? String) == id }
          UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func withdraw(requestId: String, completion: @escaping () -> Void) {
    let center = UNUserNotificationCenter.current()
    center.getDeliveredNotifications { notifications in
      let ids = notifications.filter {
        ($0.request.content.userInfo["requestId"] as? String) == requestId
      }.map { $0.request.identifier }
      center.removeDeliveredNotifications(withIdentifiers: ids)
      completion()
    }
  }

  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    if userInfo["kind"] as? String == "withdraw", let requestId = userInfo["requestId"] as? String {
      withdraw(requestId: requestId) { completionHandler(.newData) }
      return
    }
    super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let info = response.notification.request.content.userInfo
    let action = response.actionIdentifier
    // Local notifications are owned by the Flutter plugin. FCM body taps are
    // owned by firebase_messaging; only our remote approval buttons enter here.
    if info["slug"] != nil && info["aps"] != nil && (action == "allow" || action == "deny") {
      let data = info.reduce(into: [String: Any]()) { result, entry in
        if let key = entry.key as? String { result[key] = entry.value }
      }
      let event: [String: Any] = ["data": data, "actionId": action, "notificationId": response.notification.request.identifier]
      pendingActions.append(event)
      if actionsReady, let channel = actionChannel {
        channel.invokeMethod("action", arguments: event)
      }
      completionHandler()
      return
    }
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}
