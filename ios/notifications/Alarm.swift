//
//  Alarm.swift
//  notifications
//
//  Created by Konstanius on 21.03.24.
//

import Foundation
import SQLite
import Gzip

class Alarm {
    var id: String
    var type: String
    var word: String
    var date: Date
    var number: Int
    var address: String
    var notes: [String]
    var units: [Int]
    var responses: [Int: AlarmResponse]
    var updated: Date

    init(id: String, type: String, word: String, date: Date, number: Int, address: String, notes: [String], units: [Int], responses: [Int: AlarmResponse], updated: Date) {
        self.id = id
        self.type = type
        self.word = word
        self.date = date
        self.number = number
        self.address = address
        self.notes = notes
        self.units = units
        self.responses = responses
        self.updated = updated
    }

    static let jsonShorts = [
        "server": "s",
        "id": "i",
        "type": "t",
        "word": "w",
        "date": "d",
        "number": "n",
        "address": "a",
        "notes": "no",
        "units": "u",
        "responses": "r",
        "updated": "up",
    ]

    init(json: [String: Any]) {
        self.id = json[Alarm.jsonShorts["server"]!] as! String + " " + String(json[Alarm.jsonShorts["id"]!] as! Int)
        self.type = json[Alarm.jsonShorts["type"]!] as! String
        self.word = json[Alarm.jsonShorts["word"]!] as! String
        self.date = Date(timeIntervalSince1970: TimeInterval(json[Alarm.jsonShorts["date"]!] as! Int))
        self.number = json[Alarm.jsonShorts["number"]!] as! Int
        self.address = json[Alarm.jsonShorts["address"]!] as! String
        self.notes = json[Alarm.jsonShorts["notes"]!] as! [String]
        self.units = json[Alarm.jsonShorts["units"]!] as! [Int]
        self.updated = Date(timeIntervalSince1970: TimeInterval(json[Alarm.jsonShorts["updated"]!] as! Int))
        self.responses = {
            var result = [Int: AlarmResponse]()
            let decoded = json[Alarm.jsonShorts["responses"]!] as! [String: Any]
            decoded.forEach { key, value in
                let response = AlarmResponse(json: value as! [String: Any])
                result[Int(key)!] = response
            }
            return result
        }()
    }

    func toJson() -> [String: Any] {
        let tempServer = id.split(separator: " ")[0]
        let tempId = Int(id.split(separator: " ")[1])!
        return [
            Alarm.jsonShorts["id"]!: tempId,
            Alarm.jsonShorts["server"]!: tempServer,
            Alarm.jsonShorts["type"]!: type,
            Alarm.jsonShorts["word"]!: word,
            Alarm.jsonShorts["date"]!: Int(date.timeIntervalSince1970),
            Alarm.jsonShorts["number"]!: number,
            Alarm.jsonShorts["address"]!: address,
            Alarm.jsonShorts["notes"]!: notes,
            Alarm.jsonShorts["units"]!: units,
            Alarm.jsonShorts["updated"]!: Int(updated.timeIntervalSince1970),
            Alarm.jsonShorts["responses"]!: {
                var result = [String: Any]()
                responses.forEach { key, value in
                    result[String(key)] = value.toJson()
                }
                return result
            }()
        ]
    }

    static func inflateFromString(input: String) -> Alarm {
        let decodeBase64Json = Data(base64Encoded: input)!
        let decodedZipJson = try! decodeBase64Json.gunzipped()
        let decodedUtf8 = String(data: decodedZipJson, encoding: .utf8)!
        let decodedJson = try! JSONSerialization.jsonObject(with: decodedUtf8.data(using: .utf8)!, options: []) as! [String: Any]
        let alarm = Alarm(json: decodedJson)
        return alarm
    }

    func getAlertOption(prefs: [String: Any], shouldNotify: Bool) -> AlarmOption {
        let now = Date()
        if date > now.addingTimeInterval(-15 * 60) {
            if word.starts(with: "Test") {
                if prefs["alarms_testsMuted"] as? Bool == true {
                    return .silent
                }
            } else {
                if prefs["alarms_muted"] as? Bool == true {
                    return .silent
                }
            }

            return shouldNotify ? .alert : .silent
        }
        if date > now.addingTimeInterval(-24 * 60 * 60) {
            return .silent
        }
        return .none
    }

    enum AlarmOption {
        case alert
        case silent
        case none
    }

    static func insert(alarm: Alarm) {
        let alarms = Table("Alarm")
        let id = Expression<String>("id")
        let type = Expression<String>("type")
        let word = Expression<String>("word")
        let date = Expression<Int>("date")
        let number = Expression<Int>("number")
        let address = Expression<String>("address")
        let notes = Expression<String>("notes")
        let units = Expression<String>("units")
        let responses = Expression<String>("responses")
        let updated = Expression<Int>("updated")

        var jsonEncodedNotes = "[]"
        if let jsonData = try? JSONSerialization.data(withJSONObject: alarm.notes, options: []) {
            jsonEncodedNotes = String(data: jsonData, encoding: .utf8)!
        }

        var jsonEncodedUnits = "[]"
        if let jsonData = try? JSONSerialization.data(withJSONObject: alarm.units, options: []) {
            jsonEncodedUnits = String(data: jsonData, encoding: .utf8)!
        }

        var jsonEncodedResponses = [String: Any]()
        alarm.responses.forEach { key, value in
            jsonEncodedResponses[String(key)] = value.toJson()
        }
        var jsonEncodedResponsesString = "{}"
        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonEncodedResponses, options: []) {
            jsonEncodedResponsesString = String(data: jsonData, encoding: .utf8)!
        }

        let result = try? database!.run(alarms.insert(
            id <- alarm.id,
            type <- alarm.type,
            word <- alarm.word,
            date <- Int(alarm.date.timeIntervalSince1970),
            number <- alarm.number,
            address <- alarm.address,
            notes <- jsonEncodedNotes,
            units <- jsonEncodedUnits,
            responses <- jsonEncodedResponsesString,
            updated <- Int(alarm.updated.timeIntervalSince1970)
        ))

        if result == nil {
            update(alarm: alarm)
        }
    }

    static func update(alarm: Alarm) {
        let alarms = Table("Alarm")
        let id = Expression<String>("id")
        let type = Expression<String>("type")
        let word = Expression<String>("word")
        let date = Expression<Int>("date")
        let number = Expression<Int>("number")
        let address = Expression<String>("address")
        let notes = Expression<String>("notes")
        let units = Expression<String>("units")
        let responses = Expression<String>("responses")
        let updated = Expression<Int>("updated")

        var jsonEncodedNotes = "[]"
        if let jsonData = try? JSONSerialization.data(withJSONObject: alarm.notes, options: []) {
            jsonEncodedNotes = String(data: jsonData, encoding: .utf8)!
        }

        var jsonEncodedUnits = "[]"
        if let jsonData = try? JSONSerialization.data(withJSONObject: alarm.units, options: []) {
            jsonEncodedUnits = String(data: jsonData, encoding: .utf8)!
        }

        var jsonEncodedResponses = [String: Any]()
        alarm.responses.forEach { key, value in
            jsonEncodedResponses[String(key)] = value.toJson()
        }
        var jsonEncodedResponsesString = "{}"
        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonEncodedResponses, options: []) {
            jsonEncodedResponsesString = String(data: jsonData, encoding: .utf8)!
        }

        let result = try? database!.run(alarms.filter(id == alarm.id).update(
            type <- alarm.type,
            word <- alarm.word,
            date <- Int(alarm.date.timeIntervalSince1970),
            number <- alarm.number,
            address <- alarm.address,
            notes <- jsonEncodedNotes,
            units <- jsonEncodedUnits,
            responses <- jsonEncodedResponsesString,
            updated <- Int(alarm.updated.timeIntervalSince1970)
        ))
    }
}

class AlarmResponse {
    var note: String
    var time: Int
    var responses: [Int: AlarmResponseType]

    init(note: String, time: Int, responses: [Int: AlarmResponseType]) {
        self.note = note
        self.time = time
        self.responses = responses
    }

    static let jsonShorts = [
        "note": "n",
        "time": "t",
        "responses": "r",
    ]

    init(json: [String: Any]) {
        self.note = json[AlarmResponse.jsonShorts["note"]!] as! String
        self.time = json[AlarmResponse.jsonShorts["time"]!] as! Int
        self.responses = {
            var result = [Int: AlarmResponseType]()
            let decoded = json[AlarmResponse.jsonShorts["responses"]!] as! [String: Any]
            decoded.forEach { key, value in
                result[Int(key)!] = AlarmResponseType(rawValue: value as! Int)!
            }
            return result
        }()
    }

    func toJson() -> [String: Any] {
        return [
            AlarmResponse.jsonShorts["note"]!: note,
            AlarmResponse.jsonShorts["time"]!: time,
            AlarmResponse.jsonShorts["responses"]!: {
                var result = [String: Any]()
                responses.forEach { key, value in
                    result[String(key)] = value.rawValue
                }
                return result
            }()
        ]
    }

    enum AlarmResponseType: Int {
        case onStation = 0
        case under5 = 1
        case under10 = 2
        case under15 = 3
        case onCall = 4
        case notReady = 5
        case notSet = 6
    }
}
