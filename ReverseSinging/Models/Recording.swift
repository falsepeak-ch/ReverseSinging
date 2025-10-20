//
//  Recording.swift
//  ReverseSinging
//
//  Data model for individual recordings
//

import Foundation

struct Recording: Identifiable, Codable {
    let id: UUID
    let url: URL
    let duration: TimeInterval
    let createdAt: Date
    let type: RecordingType

    enum RecordingType: String, Codable {
        case original = "Original"
        case reversed = "Reversed"
        case attempt = "Attempt"
        case imported = "Imported"
    }

    init(id: UUID = UUID(), url: URL, duration: TimeInterval, type: RecordingType) {
        self.id = id
        self.url = url
        self.duration = duration
        self.createdAt = Date()
        self.type = type
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}
