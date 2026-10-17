import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    UNUserNotificationCenter.current().delegate = self
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MedicineSettings") {
      let channel = FlutterMethodChannel(name: "medicine_reminder/settings", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        if call.method == "medicineStorageDirectory" {
          do {
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            var directory = support.appendingPathComponent("PrivateMedicines", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try directory.setResourceValues(values)
            result(directory.path)
          } catch {
            result(FlutterError(code: "storage_unavailable", message: "Private medicine storage is unavailable", details: nil))
          }
          return
        }
        guard call.method == "openNotificationSettings" else { result(FlutterMethodNotImplemented); return }
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
        result(nil)
      }
    }
  }
}
