//
//  AudioSession.swift
//  ReverseSinging
//
//  Data model for a complete reverse singing session
//

import Foundation

struct AudioSession: Identifiable, Codable {
    let id: UUID
    var name: String
    let createdAt: Date
    var recordings: [Recording]

    init(id: UUID = UUID(), name: String? = nil) {
        self.id = id
        self.name = name ?? "Session"
        self.createdAt = Date()
        self.recordings = []
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    var originalRecording: Recording? {
        recordings.first { $0.type == .original || $0.type == .imported }
    }

    var reversedRecording: Recording? {
        recordings.first { $0.type == .reversed }
    }

    var attemptRecording: Recording? {
        recordings.first { $0.type == .attempt }
    }

    mutating func addRecording(_ recording: Recording) {
        recordings.append(recording)
    }

    mutating func removeRecording(_ recording: Recording) {
        recordings.removeAll { $0.id == recording.id }
    }
}
