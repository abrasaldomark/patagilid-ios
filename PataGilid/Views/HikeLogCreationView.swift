//
//  HikeLogCreationView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/28/26.
//

import SwiftUI

/// Modal sheet for recording a climb attempt — date, summit count, and DNF count.
struct HikeLogCreationView: View {
    let mountain: Mountain
    @StateObject private var viewModel = HikeLogViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    summitBanner
                    activityForm
                    
                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }
                    
                    submitButton
                        .padding(.bottom, 20)
                }
            }
            .navigationTitle("Log Ascent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isSaving)
                }
            }
            .onChange(of: viewModel.didCompleteSuccess) { _, success in
                if success { dismiss() }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var summitBanner: some View {
        HStack(spacing: 16) {
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 28))
                .foregroundColor(.emeraldGreen)
                .frame(width: 56, height: 56)
                .background(Color.emeraldGreen.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("TARGET SUMMIT")
                    .font(.caption2)
                    .fontWeight(.black)
                    .foregroundColor(.gray)
                    .tracking(1.5)
                
                Text(mountain.name)
                    .font(.title3)
                    .fontWeight(.black)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text("\(mountain.elevationMASL) MASL")
                    .font(.caption)
                    .fontWeight(.heavy)
                    .foregroundColor(.teal)
                
                Text(mountain.region)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding()
        .background(Color.secondary.opacity(0.07))
        .cornerRadius(16)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var activityForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Parameters")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                // Date & Time Start
                DatePicker(
                    "Start",
                    selection: $viewModel.dateTimeStart,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .padding()
                
                Divider().padding(.leading)
                
                // Date & Time End
                DatePicker(
                    "End",
                    selection: $viewModel.dateTimeEnd,
                    in: viewModel.dateTimeStart...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .padding()
                
                Divider().padding(.leading)
                
                // Outcome selector — mutually exclusive
                VStack(alignment: .leading, spacing: 10) {
                    Text("Climb Outcome")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        outcomeCard(.summited)
                        outcomeCard(.turnedBack)
                    }
                }
                .padding()
            }
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(14)
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private func outcomeCard(_ option: ClimbOutcome) -> some View {
        let isSelected = viewModel.outcome == option
        let accentColor: Color = option == .summited ? .orange : .red
        
        Button {
            viewModel.outcome = option
        } label: {
            VStack(spacing: 8) {
                Image(systemName: option.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? accentColor : .gray)
                Text(option.rawValue)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? accentColor : .gray)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: viewModel.outcome)
    }
    
    private var submitButton: some View {
        Button {
            viewModel.submitLog(for: mountain.id)
        } label: {
            HStack(spacing: 10) {
                if viewModel.isSaving {
                    ProgressView().tint(.white)
                    Text("Saving record...")
                } else {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Save Climb Record")
                }
            }
            .font(.headline)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(viewModel.isSaving ? Color.gray : Color.emeraldGreen)
            .cornerRadius(14)
            .shadow(color: viewModel.isSaving ? .clear : Color.emeraldGreen.opacity(0.28),
                    radius: 8, x: 0, y: 4)
        }
        .disabled(viewModel.isSaving)
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isSaving)
    }
    
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.subheadline)
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.12))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

#Preview {
    HikeLogCreationView(mountain: Mountain(
        id: "preview",
        name: "Mt. Pulag",
        description: "Sea of Clouds",
        elevationMASL: 2928,
        latitude: 16.59,
        longitude: 120.89,
        region: "CAR",
        islandGroup: .luzon,
        difficultyLevel: "3/9",
        trailClass: "Class 1-2"
    ))
}
