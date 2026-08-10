import SwiftUI

struct SponsorsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @State private var showFullImage = false
    
    var body: some View {
        ZStack {
            NavigationView {
            List {
                Section {
                    Text("Thank you to our supporters who help keep PataGilid running!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
                
                Section {
                    HStack(spacing: 16) {
                        Button {
                            showFullImage = true
                        } label: {
                            Image("team_papang_logo")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(Circle())
                                .background(
                                    Circle()
                                        .fill(Color(UIColor.secondarySystemBackground))
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Team Papang")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Davao City")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            if let url = URL(string: "https://www.facebook.com/profile.php?id=61553853326927") {
                                openURL(url)
                            }
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                                .font(.system(size: 20))
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Donators & Sponsors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            
            if showFullImage {
                Color.black.opacity(0.9)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showFullImage = false
                    }
                
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { showFullImage = false }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding()
                    }
                    Spacer()
                    Image("team_papang_logo")
                        .resizable()
                        .scaledToFit()
                        .padding()
                    Spacer()
                }
            }
        }
    }
}
}

#Preview {
    SponsorsView()
}
