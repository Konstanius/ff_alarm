//
//  SettingsNotificationData.swift
//  notifications
//
//  Created by Konstanius on 14.04.24.
//

import Foundation
import SQLite

class SettingsNotificationData {
    var stationId: String
    var manualOverride: Int
    var calendar: [CalendarEntry]
    var enabledMode: Int
    var shiftPlan: [ShiftPlanEntry]
    var geofencing: [GeofencingEntry]

    init(stationId: String, manualOverride: Int, calendar: [CalendarEntry], enabledMode: Int, shiftPlan: [ShiftPlanEntry], geofencing: [GeofencingEntry]) {
        self.stationId = stationId
        self.manualOverride = manualOverride
        self.calendar = calendar
        self.enabledMode = enabledMode
        self.shiftPlan = shiftPlan
        self.geofencing = geofencing
    }

    static let jsonShorts = [
        "stationId": "s",
        "manualOverride": "m",
        "calendar": "c",
        "enabledMode": "e",
        "shiftPlan": "sp",
        "geofencing": "g"
    ]

    static func generateFromJson(stationId: String, json: [String: Any]) -> SettingsNotificationData {
        var manualOverride = 1
        if let manualOverrideJson = json[jsonShorts["manualOverride"]!] as? Int {
            manualOverride = manualOverrideJson
        }

        var now = Date()
        var calendar = [CalendarEntry]()
        if let calendarJson = json[jsonShorts["calendar"]!] as? [String] {
            for entry in calendarJson {
                let splits = entry.split(separator: ";")
                if splits.count < 2 {
                    continue
                }
                let start = Date(timeIntervalSince1970: Double(splits[0])! / 1000)
                let end = Date(timeIntervalSince1970: Double(splits[1])! / 1000)
                if end > now && end > start {
                    calendar.append(CalendarEntry(start: start, end: end))
                } else {
                }
            }
        }

        var enabledMode = 0
        if let enabledModeJson = json[jsonShorts["enabledMode"]!] as? Int {
            enabledMode = enabledModeJson
        }

        var shiftPlan = [ShiftPlanEntry]()
        if let shiftPlanJson = json[jsonShorts["shiftPlan"]!] as? [String] {
            for entry in shiftPlanJson {
                let splits = entry.split(separator: ";")
                if splits.count < 3 {
                    continue
                }
                let day = Int(splits[0])!
                let start = Int(splits[1])!
                let end = Int(splits[2])!
                if start < end {
                    shiftPlan.append(ShiftPlanEntry(day: day, start: start, end: end))
                }
            }
        }

        var geofencing = [GeofencingEntry]()
        if let geofencingJson = json[jsonShorts["geofencing"]!] as? [String] {
            for entry in geofencingJson {
                let splits = entry.split(separator: ";")
                if splits.count < 3 {
                    continue
                }
                let latitude = Double(splits[0])!
                let longitude = Double(splits[1])!
                let radius = Double(splits[2])!
                geofencing.append(GeofencingEntry(latitude: latitude, longitude: longitude, radius: radius))
            }
        }

        return SettingsNotificationData(stationId: stationId, manualOverride: manualOverride, calendar: calendar, enabledMode: enabledMode, shiftPlan: shiftPlan, geofencing: geofencing)
    }

    static func shouldNotifyForAlarmRegardless(alarm: Alarm) -> Bool {
        var unitsTable = Table("Unit")
        var stationsTable = Table("Station")
        var personsTable = Table("Person")

        var stations = Set<String>()
        if !alarm.units.isEmpty {
            var unitIdsWithServerPrefix = [String]()
            let server = alarm.id.split(separator: " ")[0]
            alarm.units.forEach { unitId in
                unitIdsWithServerPrefix.append(server + " " + String(unitId))
            }

            var id = Expression<String>("id")
            var stationId = Expression<Int>("stationId")

            var unitResults = try? database!.prepare(unitsTable.select(id, stationId).filter(unitIdsWithServerPrefix.contains(id)))
            if unitResults == nil {
                return true
            }

            let prefsRegisteredUsers = prefs!["registered_users"] as? String ?? "[]"
            let registeredUsers = try? JSONSerialization.jsonObject(with: prefsRegisteredUsers.data(using: .utf8)!, options: []) as? [String]
            if registeredUsers == nil {
                return false
            }

            var personIdForThisAlarm = ""
            for user in registeredUsers! {
                if user.starts(with: server) {
                    personIdForThisAlarm = user
                    break
                }
            }
            if personIdForThisAlarm.isEmpty {
                return false
            }

            var personId = Expression<String>("id")
            var personAllowedUnits = Expression<String>("allowedUnits")
            var personResults = try? database!.prepare(personsTable.select(personAllowedUnits).filter(personId == personIdForThisAlarm))
            if personResults == nil {
                return true
            }

            var allowedUnits = Set<String>()
            let firstRow = personResults!.makeIterator().next()!
            let allowedUnitsString = firstRow[personAllowedUnits]
            let allowedUnitsDecoded = try? JSONSerialization.jsonObject(with: allowedUnitsString.data(using: .utf8)!, options: []) as? [Any]
            if allowedUnitsDecoded == nil {
                return false
            }
            allowedUnitsDecoded!.forEach { unit in
                allowedUnits.insert(server + " " + String(unit as! Int))
            }

            unitResults!.forEach { row in
                if !allowedUnits.contains(row[id]) {
                    return
                }
                stations.insert(server + " " + String(row[stationId]))
            }
        } else {
            var id = Expression<String>("id")
            var result = try? database!.prepare(stationsTable.select(id))
            if result == nil {
                return true
            }

            result!.forEach { row in
                stations.insert(row[id])
            }
        }

        if stations.isEmpty {
            return true
        }

        let allSettings = SettingsNotificationData.getAll()
        var includedSettings = [String: SettingsNotificationData]()
        stations.forEach { stationId in
            if allSettings[stationId] != nil {
                includedSettings[stationId] = allSettings[stationId]
            }
        }

        if includedSettings.isEmpty {
            return true
        }

        var latitude: Double? = nil
        var longitude: Double? = nil
        let locationPath = sharedContainer!.appendingPathComponent("last_location.txt")
        if FileManager.default.fileExists(atPath: locationPath.path) {
            let location = try? String(contentsOf: locationPath)
            if location != nil {
                let splits = location!.split(separator: ",")
                if splits.count == 3 {
                    let time = Int(splits[2])!
                    let now = Date().timeIntervalSince1970 * 1000
                    if Int(now) - time < 1000 * 60 * 15 {
                        latitude = Double(splits[0])!
                        longitude = Double(splits[1])!
                    }
                }
            }
        }

        for (_, settings) in includedSettings {
            if settings.shouldNotify(latitude: latitude, longitude: longitude) {
                return true
            }
        }

        return false
    }

    func shouldNotify(latitude: Double?, longitude: Double?) -> Bool {
        if manualOverride == 0 {
            return false
        }
        if manualOverride == 2 {
            return true
        }

        let now = Date()
        for entry in calendar {
            if entry.isInRange(now) {
                return false
            }
        }

        if enabledMode == 0 {
            return false
        }

        if enabledMode == 1 || enabledMode == 2 {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute, .second], from: now)
            let millis = components.hour! * 60 * 60 * 1000 + components.minute! * 60 * 1000 + components.second! * 1000
            for entry in shiftPlan {
                if entry.isInRange(now) {
                    return enabledMode == 1
                }
            }

            return enabledMode == 2
        }

        if enabledMode == 3 && latitude != nil && longitude != nil {
            for entry in geofencing {
                if entry.isInRange(latitude!, longitude!) {
                    return true
                }
            }

            return false
        }

        return true
    }

    static func getAll() -> [String: SettingsNotificationData] {
        let filePath = sharedContainer!.appendingPathComponent("notification_settings.json")
        if !FileManager.default.fileExists(atPath: filePath.path) {
            return [:]
        }

        let json = try! JSONSerialization.jsonObject(with: Data(contentsOf: filePath), options: []) as? [String: Any]
        var result = [String: SettingsNotificationData]()
        json!.forEach { (stationId, settingsJson) in
            result[stationId] = generateFromJson(stationId: stationId, json: settingsJson as! [String: Any])
        }

        return result
    }
}

class CalendarEntry {
    var start: Date
    var end: Date

    init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    func isInRange(_ date: Date) -> Bool {
        return date >= start && date <= end
    }


}

class ShiftPlanEntry {
    var day: Int
    var start: Int
    var end: Int

    init(day: Int, start: Int, end: Int) {
        self.day = day
        self.start = start
        self.end = end
    }

    func isInRange(_ date: Date) -> Bool {
        let calendar = Calendar.current
        var weekday = calendar.component(.weekday, from: date)
        weekday = weekday == 1 ? 7 : weekday - 1
        if weekday != day {
            return false
        }

        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let millis = components.hour! * 60 * 60 * 1000 + components.minute! * 60 * 1000 + components.second! * 1000
        return millis >= start && millis <= end
    }
}

class GeofencingEntry {
    var latitude: Double
    var longitude: Double
    var radius: Double

    init(latitude: Double, longitude: Double, radius: Double) {
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
    }

    func isInRange(_ latitude: Double, _ longitude: Double) -> Bool {
        return distanceBetween(startLatitude: self.latitude, startLongitude: self.longitude, endLatitude: latitude, endLongitude: longitude) <= radius
    }
}

func distanceBetween(startLatitude: Double, startLongitude: Double, endLatitude: Double, endLongitude: Double) -> Double {
    let earthRadius = 6378137.0
    let dLat = toRadians(endLatitude - startLatitude)
    let dLon = toRadians(endLongitude - startLongitude)

    let a = pow(sin(dLat / 2), 2) + pow(sin(dLon / 2), 2) * cos(toRadians(startLatitude)) * cos(toRadians(endLatitude))
    let c = 2 * asin(sqrt(a))

    return earthRadius * c
}

func toRadians(_ degree: Double) -> Double {
    return degree * .pi / 180.0
}

