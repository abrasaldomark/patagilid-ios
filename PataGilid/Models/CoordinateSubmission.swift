import Foundation
import SwiftData
import FirebaseFirestore

enum SubmissionStatus: String, Codable, CaseIterable {
    case pending = "PENDING"
    case approved = "APPROVED"
    case rejected = "REJECTED"
    case duplicate = "DUPLICATE"
}

@Model final class CoordinateSubmission: Identifiable, Hashable {
    @Attribute(.unique) var id: String
    var mountainId: String
    var mountainName: String?
    var region: String?
    var latitude: Double
    var longitude: Double
    var contributorEmail: String
    var contributorName: String?
    var status: SubmissionStatus
    var createdAt: Date?
    var submittedAt: Date?
    var processedAt: Date?
    
    init(
        id: String,
        mountainId: String,
        mountainName: String? = nil,
        region: String? = nil,
        latitude: Double,
        longitude: Double,
        contributorEmail: String,
        contributorName: String? = nil,
        status: SubmissionStatus = .pending,
        createdAt: Date? = nil,
        submittedAt: Date? = nil,
        processedAt: Date? = nil
    ) {
        self.id = id
        self.mountainId = mountainId
        self.mountainName = mountainName
        self.region = region
        self.latitude = latitude
        self.longitude = longitude
        self.contributorEmail = contributorEmail
        self.contributorName = contributorName
        self.status = status
        self.createdAt = createdAt
        self.submittedAt = submittedAt
        self.processedAt = processedAt
    }
    
    var displayDate: Date {
        return createdAt ?? submittedAt ?? Date()
    }
    
    var displayContributorName: String? {
        if let name = contributorName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        return contributorEmail.formattedFirstName
    }
}

// MARK: - Codable Conformance
extension CoordinateSubmission: Codable {
    enum CodingKeys: String, CodingKey {
        case id, mountainId, mountainName, region
        case latitude, longitude
        case contributorEmail, contributorName
        case status, createdAt, submittedAt, processedAt
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        let mountainId = try container.decode(String.self, forKey: .mountainId)
        let mountainName = try container.decodeIfPresent(String.self, forKey: .mountainName)
        let region = try container.decodeIfPresent(String.self, forKey: .region)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        let contributorEmail = try container.decode(String.self, forKey: .contributorEmail)
        let contributorName = try container.decodeIfPresent(String.self, forKey: .contributorName)
        let status = try container.decodeIfPresent(SubmissionStatus.self, forKey: .status) ?? .pending
        
        let createdAt: Date?
        if let dateVal = try? container.decodeIfPresent(Date.self, forKey: .createdAt) {
            createdAt = dateVal
        } else if let timeInterval = try? container.decodeIfPresent(TimeInterval.self, forKey: .createdAt) {
            createdAt = Date(timeIntervalSince1970: timeInterval)
        } else {
            createdAt = nil
        }
        
        let submittedAt: Date?
        if let dateVal = try? container.decodeIfPresent(Date.self, forKey: .submittedAt) {
            submittedAt = dateVal
        } else if let timeInterval = try? container.decodeIfPresent(TimeInterval.self, forKey: .submittedAt) {
            submittedAt = Date(timeIntervalSince1970: timeInterval)
        } else {
            submittedAt = nil
        }
        
        let processedAt: Date?
        if let dateVal = try? container.decodeIfPresent(Date.self, forKey: .processedAt) {
            processedAt = dateVal
        } else if let timeInterval = try? container.decodeIfPresent(TimeInterval.self, forKey: .processedAt) {
            processedAt = Date(timeIntervalSince1970: timeInterval)
        } else {
            processedAt = nil
        }
        
        self.init(
            id: id,
            mountainId: mountainId,
            mountainName: mountainName,
            region: region,
            latitude: latitude,
            longitude: longitude,
            contributorEmail: contributorEmail,
            contributorName: contributorName,
            status: status,
            createdAt: createdAt,
            submittedAt: submittedAt,
            processedAt: processedAt
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(mountainId, forKey: .mountainId)
        try container.encodeIfPresent(mountainName, forKey: .mountainName)
        try container.encodeIfPresent(region, forKey: .region)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(contributorEmail, forKey: .contributorEmail)
        try container.encodeIfPresent(contributorName, forKey: .contributorName)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(submittedAt, forKey: .submittedAt)
        try container.encodeIfPresent(processedAt, forKey: .processedAt)
    }
}
