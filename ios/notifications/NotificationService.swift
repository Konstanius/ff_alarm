//
//  NotificationService.swift
//  notifications
//
//  Created by Konstanius on 13.03.24.
//

import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let bestAttemptContent = bestAttemptContent {
            bestAttemptContent.title = "Test Alarmierung"
            bestAttemptContent.body = "Dies ist eine Test Alarmierung"
            
            let customSound = UNNotificationSound.criticalSoundNamed(UNNotificationSoundName(rawValue: "res_alarm_1.mp3"), withAudioVolume: 1.0)
            bestAttemptContent.sound = customSound
            
            if #available(iOSApplicationExtension 15.0, *) {
                bestAttemptContent.interruptionLevel = .timeSensitive
            }

            contentHandler(bestAttemptContent)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            bestAttemptContent.title = "Test Alarmierung"
            bestAttemptContent.body = "Dies ist eine Test Alarmierung"
            contentHandler(bestAttemptContent)
        }
    }

}
