//
//  SupportViewModel.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/31/26.
//

import SwiftUI
import Combine
import FirebaseFirestore

/// Fetches the developer support/donation config from `app_config/support` in Firestore.
/// The QR image is hosted in Firebase Storage; only the download URL is stored in Firestore
/// so it can be updated remotely without requiring an app release.
@MainActor
class SupportViewModel: ObservableObject {
    @Published var qrImageUrl: URL? = nil
    @Published var caption: String = "Metrobank · Mark Abrasaldo"
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let db = Firestore.firestore()

    func fetchSupportConfig() {
        guard qrImageUrl == nil else { return } // Already loaded
        isLoading = true
        errorMessage = nil

        db.collection("app_config").document("support").getDocument { [weak self] snapshot, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isLoading = false

                if let error {
                    self.errorMessage = "Could not load QR code: \(error.localizedDescription)"
                    return
                }

                guard let data = snapshot?.data() else {
                    self.errorMessage = "Support config not found. Please try again later."
                    return
                }

                if let urlString = data["qrImageUrl"] as? String,
                   let url = URL(string: urlString) {
                    self.qrImageUrl = url
                }

                if let caption = data["caption"] as? String, !caption.isEmpty {
                    self.caption = caption
                }
            }
        }
    }
}
