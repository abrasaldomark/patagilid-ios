//
//  DonationQRView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/31/26.
//

import SwiftUI
import Photos

/// A modal sheet displaying the developer's bank QR code for optional donations.
/// The QR image URL and caption are fetched dynamically from Firestore so they
/// can be updated remotely without requiring an app release.
struct DonationQRView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SupportViewModel()

    @State private var savedToPhotos: Bool = false
    @State private var saveError: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {

                    // MARK: - Header
                    VStack(spacing: 10) {
                        Text("⛰️")
                            .font(.system(size: 56))

                        Text("Pang akyat lang")
                            .font(.title2)
                            .fontWeight(.black)

                        Text("PataGilid is completely free.\nIf it helped your climbs, a small treat is deeply appreciated!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 8)

                    // MARK: - QR Code Card
                    VStack(spacing: 16) {
                        if viewModel.isLoading {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(width: 260, height: 260)
                                .overlay(
                                    ProgressView()
                                        .tint(.gliderBlue)
                                        .scaleEffect(1.3)
                                )

                        } else if let error = viewModel.errorMessage {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.secondary.opacity(0.08))
                                .frame(width: 260, height: 260)
                                .overlay(
                                    VStack(spacing: 10) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 36))
                                            .foregroundColor(.orange)
                                        Text(error)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 16)
                                    }
                                )

                        } else if let url = viewModel.qrImageUrl {
                            CachedAsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .interpolation(.high)
                                        .scaledToFit()
                                        .frame(width: 260, height: 260)
                                        .padding(12)
                                        .background(Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
                                default:
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.secondary.opacity(0.1))
                                        .frame(width: 260, height: 260)
                                        .overlay(ProgressView().tint(.gliderBlue))
                                }
                            }
                        }

                        // Caption
                        Text(viewModel.caption)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text("Scan with your banking app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // MARK: - Save to Photos Button
                    if viewModel.qrImageUrl != nil && !viewModel.isLoading {
                        VStack(spacing: 10) {
                            Button {
                                saveQRToPhotos()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: savedToPhotos ? "checkmark.circle.fill" : "square.and.arrow.down.fill")
                                    Text(savedToPhotos ? "Saved to Photos!" : "Save QR to Photos")
                                        .fontWeight(.semibold)
                                }
                                .font(.subheadline)
                                .foregroundColor(savedToPhotos ? .green : .gliderBlue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background((savedToPhotos ? Color.green : Color.gliderBlue).opacity(0.12))
                                .cornerRadius(12)
                            }
                            .animation(.easeInOut(duration: 0.2), value: savedToPhotos)
                            .padding(.horizontal)

                            if let saveError {
                                Text(saveError)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                    }

                    // MARK: - Thank You Note
                    Text("Thank you for supporting PataGilid! 🏔️🙏\nEvery peso helps keep our mountain list growing.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 16)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Support the Developer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(.gliderBlue)
                }
            }
            .onAppear {
                viewModel.fetchSupportConfig()
            }
        }
    }

    // MARK: - Save QR to Photos Library

    private func saveQRToPhotos() {
        guard let url = viewModel.qrImageUrl else { return }

        // Use cached image if available via UIImage download
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else {
                    await MainActor.run { saveError = "Could not process QR image." }
                    return
                }
                let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                guard status == .authorized || status == .limited else {
                    await MainActor.run { saveError = "Please allow Photos access in Settings to save the QR code." }
                    return
                }
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
                await MainActor.run {
                    savedToPhotos = true
                    saveError = nil
                    // Reset button after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        savedToPhotos = false
                    }
                }
            } catch {
                await MainActor.run {
                    saveError = "Failed to save: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    DonationQRView()
}
