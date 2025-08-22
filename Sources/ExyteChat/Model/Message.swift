//
//  Message.swift
//  Chat
//
//  Created by Alisa Mylnikova on 20.04.2022.
//

import SwiftUI

public protocol MessagePayload: Hashable, Sendable {
    func isEqual(to other: any MessagePayload) -> Bool
}

public extension MessagePayload where Self: Equatable {
    func isEqual(to other: any MessagePayload) -> Bool {
        guard let other = other as? Self else {
            return false
        }
        return self == other
    }
}

public struct Message: Identifiable, Hashable, Sendable {

    public enum Status: Equatable, Hashable, Sendable {
        case sending
        case sent
        case read
        case error(DraftMessage)

        public func hash(into hasher: inout Hasher) {
            switch self {
            case .sending:
                return hasher.combine("sending")
            case .sent:
                return hasher.combine("sent")
            case .read:
                return hasher.combine("read")
            case .error:
                return hasher.combine("error")
            }
        }

        public static func == (lhs: Message.Status, rhs: Message.Status) -> Bool {
            switch (lhs, rhs) {
            case (.sending, .sending):
                return true
            case (.sent, .sent):
                return true
            case (.read, .read):
                return true
            case ( .error(_), .error(_)):
                return true
            default:
                return false
            }
        }
    }

    public var id: String
    public var user: User
    public var status: Status?
    public var createdAt: Date

    public var text: String
    public var attachments: [Attachment]
    public var reactions: [Reaction]
    public var giphyMediaId: String?
    public var recording: Recording?
    public var replyMessage: ReplyMessage?

    public var triggerRedraw: UUID?

    public var kind: String
    public var payload: (any MessagePayload)?

    public init(id: String,
                user: User,
                status: Status? = nil,
                createdAt: Date = Date(),
                text: String = "",
                attachments: [Attachment] = [],
                giphyMediaId: String? = nil,
                reactions: [Reaction] = [],
                recording: Recording? = nil,
                replyMessage: ReplyMessage? = nil,
                kind: String = "text",
                payload: (any MessagePayload)? = nil) {

        self.id = id
        self.user = user
        self.status = status
        self.createdAt = createdAt
        self.text = text
        self.attachments = attachments
        self.giphyMediaId = giphyMediaId
        self.reactions = reactions
        self.recording = recording
        self.replyMessage = replyMessage
        self.kind = kind
        self.payload = payload
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(user)
        hasher.combine(status)
        hasher.combine(createdAt)
        hasher.combine(text)
        hasher.combine(attachments)
        hasher.combine(reactions)
        hasher.combine(giphyMediaId)
        hasher.combine(recording)
        hasher.combine(replyMessage)
        hasher.combine(triggerRedraw)
        hasher.combine(kind)
        if let payload = payload {
            hasher.combine(payload)
        }
    }

    public static func makeMessage(
        id: String,
        user: User,
        status: Status? = nil,
        draft: DraftMessage) async -> Message {
            let attachments = await draft.medias.asyncCompactMap { media -> Attachment? in
                guard let thumbnailURL = await media.getThumbnailURL() else {
                    return nil
                }
                
                switch media.type {
                case .image:
                    return Attachment(id: UUID().uuidString, url: thumbnailURL, type: .image)
                case .video:
                    guard let fullURL = await media.getURL() else {
                        return nil
                    }
                    return Attachment(id: UUID().uuidString, thumbnail: thumbnailURL, full: fullURL, type: .video)
                }
            }
            
            let giphyMediaId = draft.giphyMedia?.id
            
            return Message(
                id: id,
                user: user,
                status: status,
                createdAt: draft.createdAt,
                text: draft.text,
                attachments: attachments,
                giphyMediaId: giphyMediaId,
                recording: draft.recording,
                replyMessage: draft.replyMessage
            )
        }
}

extension Message {
    var time: String {
        DateFormatter.timeFormatter.string(from: createdAt)
    }
}

extension Message: Equatable {
    public static func == (lhs: Message, rhs: Message) -> Bool {
        if lhs.payload == nil && rhs.payload == nil {
            // continue
        } else if let lhsPayload = lhs.payload, let rhsPayload = rhs.payload {
            if !lhsPayload.isEqual(to: rhsPayload) {
                return false
            }
        } else {
            return false
        }

        return lhs.id == rhs.id &&
            lhs.user == rhs.user &&
            lhs.status == rhs.status &&
            lhs.createdAt == rhs.createdAt &&
            lhs.text == rhs.text &&
            lhs.giphyMediaId == rhs.giphyMediaId &&
            lhs.attachments == rhs.attachments &&
            lhs.reactions == rhs.reactions &&
            lhs.recording == rhs.recording &&
            lhs.replyMessage == rhs.replyMessage &&
            lhs.triggerRedraw == rhs.triggerRedraw &&
            lhs.kind == rhs.kind
    }
}

public struct Recording: Codable, Hashable, Sendable {
    public var duration: Double
    public var waveformSamples: [CGFloat]
    public var url: URL?

    public init(duration: Double = 0.0, waveformSamples: [CGFloat] = [], url: URL? = nil) {
        self.duration = duration
        self.waveformSamples = waveformSamples
        self.url = url
    }
}

public struct ReplyMessage: Codable, Identifiable, Hashable, Sendable {
    public static func == (lhs: ReplyMessage, rhs: ReplyMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.user == rhs.user &&
        lhs.createdAt == rhs.createdAt &&
        lhs.text == rhs.text &&
        lhs.attachments == rhs.attachments &&
        lhs.recording == rhs.recording
    }

    public var id: String
    public var user: User
    public var createdAt: Date

    public var text: String
    public var attachments: [Attachment]
    public var recording: Recording?

    public init(id: String,
                user: User,
                createdAt: Date,
                text: String = "",
                attachments: [Attachment] = [],
                recording: Recording? = nil) {

        self.id = id
        self.user = user
        self.createdAt = createdAt
        self.text = text
        self.attachments = attachments
        self.recording = recording
    }

    func toMessage() -> Message {
        Message(id: id, user: user, createdAt: createdAt, text: text, attachments: attachments, recording: recording)
    }
}

public extension Message {

    func toReplyMessage() -> ReplyMessage {
        ReplyMessage(id: id, user: user, createdAt: createdAt, text: text, attachments: attachments, recording: recording)
    }
}
