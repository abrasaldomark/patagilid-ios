import Foundation
import FirebaseFirestore

enum SubmissionStatus: String, Codable, CaseIterable {
    case pending = "PENDING"
    case approved = "APPROVED"
    case rejected = "REJECTED"
    case duplicate = "DUPLICATE"
}

struct CoordinateSubmission: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var mountainId: String
    var mountainName: String
    var latitude: Double
    var longitude: Double
    var contributorEmail: String
    var contributorName: String?
    var status: SubmissionStatus
    var createdAt: Date
    var processedAt: Date?
    
    var displayContributorName: String? {
        if let name = contributorName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        return contributorEmail.formattedFirstName
    }
}
