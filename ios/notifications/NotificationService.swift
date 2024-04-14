//
//  NotificationService.swift
//  notifications
//
//  Created by Konstanius on 13.03.24.
//

import UserNotifications
import SQLite

var database: Connection?
var prefs: [String: Any]?
var sharedContainer: URL?

var loggerFile: FileHandle?

func log(_ message: String) {
    loggerFile?.write((message + "\n").data(using: .utf8)!)
    loggerFile?.synchronizeFile()
}

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        if let bestAttemptContent = bestAttemptContent {
            var finished = false

            bestAttemptContent.title = "Alarmierung (Synchronisierungsfehler)"
            bestAttemptContent.body = "Eine Alarmierung wurde gesendet. Bitte überprüfe die App auf neue Alarmierungen."
            let customSound = UNNotificationSound.criticalSoundNamed(UNNotificationSoundName(rawValue: "res_alarm_1.mp3"), withAudioVolume: 1.0)
            bestAttemptContent.sound = customSound

            if #available(iOSApplicationExtension 15.0, *) {
                bestAttemptContent.interruptionLevel = .timeSensitive
            }

            defer {
                if !finished {
                    bestAttemptContent.title = "Alarmierung (Synchronisierungsfehler)"
                    bestAttemptContent.body = "Eine Alarmierung wurde gesendet. Bitte überprüfe die App auf neue Alarmierungen."
                    let customSound = UNNotificationSound.criticalSoundNamed(UNNotificationSoundName(rawValue: "res_alarm_1.mp3"), withAudioVolume: 1.0)
                    bestAttemptContent.sound = customSound

                    if #available(iOSApplicationExtension 15.0, *) {
                        bestAttemptContent.interruptionLevel = .timeSensitive
                    }
                    contentHandler(bestAttemptContent)
                }
            }
            sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.de.jena.feuerwehr.app.ffAlarm")

            loggerFile = FileHandle(forWritingAtPath: sharedContainer!.appendingPathComponent("nse.log").path)
            if loggerFile == nil {
                FileManager.default.createFile(atPath: sharedContainer!.appendingPathComponent("nse.log").path, contents: nil, attributes: nil)
                loggerFile = FileHandle(forWritingAtPath: sharedContainer!.appendingPathComponent("nse.log").path)
            }
            loggerFile?.seekToEndOfFile()

            let prefsPath = sharedContainer!.appendingPathComponent("prefs/main.json")
            prefs = try! JSONSerialization.jsonObject(with: Data(contentsOf: prefsPath), options: []) as? [String: Any]

            let dbPath = sharedContainer!.appendingPathComponent("databases/database.db")
            database = try! Connection(dbPath.path)

            let type = bestAttemptContent.userInfo["type"] as! String

            switch type {
            case "alarm":
                let alarm = Alarm.inflateFromString(input: bestAttemptContent.userInfo["alarm"] as! String)
                Alarm.insert(alarm: alarm)

                var alarmSoundPath = prefs!["alarm_soundPath"] as? String ?? "res_alarm_1"
                alarmSoundPath = alarmSoundPath + ".mp3"

                var channelKey = "alarm"
                if alarm.type.starts(with: "Test") {
                    channelKey = "test"
                }

                let shouldNotify = SettingsNotificationData.shouldNotifyForAlarmRegardless(alarm: alarm)
                let alarmOption = alarm.getAlertOption(shouldNotify: shouldNotify)
                switch alarmOption {
                case .alert:
                    bestAttemptContent.sound = UNNotificationSound.criticalSoundNamed(UNNotificationSoundName(rawValue: alarmSoundPath), withAudioVolume: 1.0)
                    if #available(iOSApplicationExtension 15.0, *) {
                        bestAttemptContent.interruptionLevel = .timeSensitive
                    }
                    break
                case .silent:
                    channelKey += "_silent"
                    bestAttemptContent.sound = nil
                    if #available(iOSApplicationExtension 15.0, *) {
                        bestAttemptContent.interruptionLevel = .passive
                    }
                    break
                case .none:
                    channelKey += "_silent"
                    bestAttemptContent.sound = nil
                    if #available(iOSApplicationExtension 15.0, *) {
                        bestAttemptContent.interruptionLevel = .passive
                    }
                    break
                }
                bestAttemptContent.categoryIdentifier = channelKey

                bestAttemptContent.title = alarm.type
                bestAttemptContent.body = alarm.word

                bestAttemptContent.userInfo["type"] = "alarm"
                let alarmData = try! JSONSerialization.data(withJSONObject: alarm.toJson(), options: [])
                bestAttemptContent.userInfo["alarm"] = String(data: alarmData, encoding: .utf8)
                bestAttemptContent.userInfo["received"] = String(Date().timeIntervalSince1970 * 1000)
                break
            default:
                break
            }

            contentHandler(bestAttemptContent)

            finished = true
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            bestAttemptContent.title = "Alarmierung (Synchronisierungsfehler)"
            bestAttemptContent.body = "Eine Alarmierung wurde gesendet. Bitte überprüfe die App auf neue Alarmierungen."
            let customSound = UNNotificationSound.criticalSoundNamed(UNNotificationSoundName(rawValue: "res_alarm_1.mp3"), withAudioVolume: 1.0)
            bestAttemptContent.sound = customSound

            if #available(iOSApplicationExtension 15.0, *) {
                bestAttemptContent.interruptionLevel = .timeSensitive
            }
            contentHandler(bestAttemptContent)
        }
    }
}
