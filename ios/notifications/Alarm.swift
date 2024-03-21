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
    var id: Int
    var type: String
    var word: String
    var date: Date
    var number: Int
    var address: String
    var notes: [String]
    var units: [Int]
    var responses: [Int: AlarmResponse]
    var updated: Date

    init(id: Int, type: String, word: String, date: Date, number: Int, address: String, notes: [String], units: [Int], responses: [Int: AlarmResponse], updated: Date) {
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
        self.id = json[Alarm.jsonShorts["id"]!] as! Int
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
        return [
            Alarm.jsonShorts["id"]!: id,
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

    func getAlertOption() -> AlarmOption {
        let now = Date()
        if date > now.addingTimeInterval(-15 * 60) {
            return .alert
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

    // insert into sqlite
    static func insert(alarm: Alarm) {
        let alarms = Table("Alarm")
        let id = Expression<Int>("id")
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

        try! database!.run(alarms.insert(
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
    }
}

class AlarmResponse {
    var note: String?
    var time: Date?
    var type: AlarmResponseType
    var stationId: Int?

    init(note: String?, time: Date?, type: AlarmResponseType, stationId: Int?) {
        self.note = note
        self.time = time
        self.type = type
        self.stationId = stationId
    }

    static let jsonShorts = [
        "note": "n",
        "time": "t",
        "type": "d",
        "stationId": "s",
    ]

    init(json: [String: Any]) {
        self.note = json[AlarmResponse.jsonShorts["note"]!] as? String
        self.time = json[AlarmResponse.jsonShorts["time"]!] as? Date
        self.type = AlarmResponseType(rawValue: json[AlarmResponse.jsonShorts["type"]!] as! Int)!
        self.stationId = json[AlarmResponse.jsonShorts["stationId"]!] as? Int
    }

    func toJson() -> [String: Any] {
        return [
            AlarmResponse.jsonShorts["note"]!: note ?? NSNull(),
            AlarmResponse.jsonShorts["time"]!: time ?? NSNull(),
            AlarmResponse.jsonShorts["type"]!: type.rawValue,
            AlarmResponse.jsonShorts["stationId"]!: stationId ?? NSNull(),
        ]
    }

    enum AlarmResponseType: Int {
        case onStation = 0
        case under5 = 1
        case under10 = 2
        case under15 = 3
        case onCall = 4
        case notReady = 5
    }
}
