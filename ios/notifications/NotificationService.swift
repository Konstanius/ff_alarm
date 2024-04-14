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
                _ = Task.init {
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

                        // if starts with "Test" or shouldNotify is false or alarm.date < now - 1h, break
                        if alarm.type.starts(with: "Test") || !shouldNotify || alarm.date < Date().addingTimeInterval(-3600) {
                            break
                        }

                        log("1")

                        guard let server = alarm.id.split(separator: " ").first else {
                            break
                        }
                        let serverHost = String(server)
                        log("2")

                        guard let authSessionFromPrefs = prefs!["auth_session_\(serverHost)"] as? String else {
                            break
                        }
                        let authSession = authSessionFromPrefs
                        log("3")

                        guard let authTokenFromPrefs = prefs!["auth_token_\(serverHost)"] as? String else {
                            break
                        }
                        let authToken = authTokenFromPrefs
                        let authHeaderRaw = "\(authSession) \(authToken)"
                        log("4")

                        guard let fcmTokenFromPrefs = prefs!["fcm_token"] as? String else {
                            break
                        }
                        let fcmTokenRaw = "I" + fcmTokenFromPrefs
                        log("5")

                        let authHeader = authHeaderRaw.data(using: .utf8)!.gzipped().base64EncodedString()
                        log("6")
                        let fcmToken = fcmTokenRaw.data(using: .utf8)!.gzipped().base64EncodedString()
                        log("7")

                        let url = URL(string: "http\(serverHost)/api/alarmGet")!
                        var request = URLRequest(url: url)
                        request.httpMethod = "POST"
                        log("8")

                        request.setValue("authorization", forHTTPHeaderField: authHeader)
                        request.setValue("fcmToken", forHTTPHeaderField: fcmToken)
                        log("9")

                        let alarmIdInt = Int(alarm.id.split(separator: " ")[1])!
                        let data: [String: Any] = ["alarmId": alarmIdInt]
                        request.httpBody = try? JSONSerialization.data(withJSONObject: data, options: [])
                        log("10")

                        let (data, response) = try? await URLSession.shared.data(for: request)
                        log("11")
                        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                            break
                        }
                        log("12")

                        let alarmData = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any]
                        log("13")
                        guard let alarmData = alarmData else {
                            break
                        }

                        log("14")
                        let alarm = Alarm(json: alarmData)
                        log("15")
                        Alarm.update(alarm: alarm)
                        log("16")


                        break
                    default:
                        break
                    }

                    finished = true
                    contentHandler(bestAttemptContent)
                }
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
