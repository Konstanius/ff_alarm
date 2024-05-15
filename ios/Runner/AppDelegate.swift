import UIKit
import Flutter
import UserNotifications
import awesome_notifications
import FirebaseMessaging
import CoreLocation
import CoreMotion


@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
            _ application: UIApplication,
            didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()

        // This function registers the desired plugins to be used within a notification background action
        SwiftAwesomeNotificationsPlugin.setPluginRegistrantCallback { registry in
            SwiftAwesomeNotificationsPlugin.register(with: registry.registrar(forPlugin: "io.flutter.plugins.awesomenotifications.AwesomeNotificationsPlugin")!)
        }

        // method channel to request criticalAlert permission
        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
        let criticalAlertChannel = FlutterMethodChannel(name: "app.feuerwehr.jena.de/methods", binaryMessenger: controller.binaryMessenger)
        criticalAlertChannel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if call.method == "requestCriticalAlertPermission" {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .provisional, .criticalAlert]) { (granted, error) in
                    if granted {
                        result(true)
                    } else {
                        result(false)
                    }
                }
            }

            else if call.method == "checkCriticalAlertPermission" {
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    if settings.criticalAlertSetting == .enabled {
                        result(true)
                    } else {
                        result(false)
                    }
                }
            }

            else if call.method == "checkMotionSensorsPermission" {
                let status = CMMotionActivityManager.authorizationStatus()
                if status == .authorized {
                    result(true)
                } else {
                    result(false)
                }
            }
        })

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
