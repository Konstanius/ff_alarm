//
//  NotificationService.swift
//  notifications
//
//  Created by Konstanius on 13.03.24.
//

import UserNotifications
import SQLite
import Foundation

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
                    if alarm.type.starts(with: "Test") || alarm.date < Date().addingTimeInterval(-3600) {
                        break
                    }

                    guard let server = alarm.id.split(separator: " ").first else {
                        break
                    }
                    let serverHost = String(server)

                    guard let authSessionFromPrefs = prefs!["auth_session_\(serverHost)"] as? Int else {
                        break
                    }
                    let authSession = String(authSessionFromPrefs)

                    guard let authTokenFromPrefs = prefs!["auth_token_\(serverHost)"] as? String else {
                        break
                    }
                    let authToken = authTokenFromPrefs
                    let authHeaderRaw = "\(authSession) \(authToken)"

                    guard let fcmTokenFromPrefs = prefs!["fcm_token"] as? String else {
                        break
                    }
                    let fcmTokenRaw = "I" + fcmTokenFromPrefs

                    let authHeader = try! authHeaderRaw.data(using: .utf8)!.gzipped().base64EncodedString()
                    let fcmToken = try! fcmTokenRaw.data(using: .utf8)!.gzipped().base64EncodedString()

                    let url = URL(string: "http\(serverHost)/api/alarmGet")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"

                    request.setValue(authHeader, forHTTPHeaderField: "authorization")
                    request.setValue(fcmToken, forHTTPHeaderField: "fcmToken")

                    let alarmIdInt = Int(alarm.id.split(separator: " ")[1])!
                    let data: [String: Any] = ["alarmId": alarmIdInt]
                    request.httpBody = try? JSONSerialization.data(withJSONObject: data, options: [])

                    do {
                        let (rData, response) = try await URLSession.shared.data(for: request)

                        guard let httpResponse = response as? HTTPURLResponse else {
                            break
                        }

                        if httpResponse.statusCode != 200 {
                            break
                        }

                        guard let alarmData = try? JSONSerialization.jsonObject(with: rData, options: []) as? [String: Any] else {
                            break
                        }

                        let newAlarm = Alarm(json: alarmData)
                        Alarm.update(alarm: newAlarm)

                        if shouldNotify {
                            break
                        }

                        var ownResponse: AlarmResponse? = nil

                        let prefsRegisteredUsers = prefs!["registered_users"] as? String ?? "[]"

                        let registeredUsers = try? JSONSerialization.jsonObject(with: prefsRegisteredUsers.data(using: .utf8)!, options: []) as? [String]
                        if registeredUsers == nil {
                            break
                        }

                        var personIdForThisAlarm = ""
                        for user in registeredUsers! {
                            if user.starts(with: server) {
                                personIdForThisAlarm = user
                                break
                            }
                        }
                        if personIdForThisAlarm.isEmpty {
                            break
                        }

                        guard let personIdInt = Int(personIdForThisAlarm.split(separator: " ")[1]) else {
                            break
                        }

                        for (key, value) in alarm.responses {
                            if key == personIdInt {
                                ownResponse = value
                                break
                            }
                        }

                        if ownResponse == nil || ownResponse!.getResponseInfo().responseType == .notSet {
                            let url2 = URL(string: "http\(serverHost)/api/alarmSetResponse")!
                            var request2 = URLRequest(url: url2)
                            request2.httpMethod = "POST"

                            request2.setValue(authHeader, forHTTPHeaderField: "authorization")
                            request2.setValue(fcmToken, forHTTPHeaderField: "fcmToken")

                            let data2: [String: Any] = ["alarmId": alarmIdInt, "responseType": 5, "note": ""]

                            request2.httpBody = try? JSONSerialization.data(withJSONObject: data2, options: [])

                            let (rData2, response2) = try await URLSession.shared.data(for: request2)
                        }
                    } catch {
                        log("Error: \(error)")
                        break
                    }
                    break
                case "fcmTest":
                    bestAttemptContent.title = "Test"
                    bestAttemptContent.body = "Test der Alarmierungs-Zustellung"
                    bestAttemptContent.sound = nil
                    if #available(iOSApplicationExtension 15.0, *) {
                        bestAttemptContent.interruptionLevel = .passive
                    }
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
