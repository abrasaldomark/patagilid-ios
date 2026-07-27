//
//  AuthViewModel.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/27/26.
//

import SwiftUI
import Combine
import FirebaseAuth
import GoogleSignIn
import FirebaseCore

/// Responsible for handling user session state, Google OAuth sign-in flows, and secure sign-out.
@MainActor
class AuthViewModel: ObservableObject {
    @Published var currentUser: FirebaseAuth.User?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    var isLoggedIn: Bool {
        return currentUser != nil
    }
    
    var userDisplayName: String {
        return currentUser?.displayName ?? currentUser?.email ?? "Mountaineer"
    }
    
    var userPhotoURL: URL? {
        return currentUser?.photoURL
    }
    
    init() {
        registerAuthStateListener()
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    /// Listens to real-time authentication session changes across app relaunches
    private func registerAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            Task { @MainActor in
                self?.currentUser = user
            }
        }
    }
    
    /// Triggers the Google OAuth native sign-in flow and authenticates against Cloud Firestore / Firebase Auth
    func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Missing Firebase Client ID in GoogleService-Info.plist."
            return
        }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Unable to locate active window to present Google Sign-In."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] signInResult, error in
            guard let self = self else { return }
            
            if let error = error {
                Task { @MainActor in
                    self.isLoading = false
                    // Ignore explicit user cancellation
                    if (error as NSError).code != GIDSignInError.canceled.rawValue {
                        self.errorMessage = "Google Sign-In failed: \(error.localizedDescription)"
                    }
                }
                return
            }
            
            guard let user = signInResult?.user,
                  let idToken = user.idToken?.tokenString else {
                Task { @MainActor in
                    self.isLoading = false
                    self.errorMessage = "Failed to retrieve authentication token from Google."
                }
                return
            }
            
            let accessToken = user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            
            Auth.auth().signIn(with: credential) { authResult, authError in
                Task { @MainActor in
                    self.isLoading = false
                    if let authError = authError {
                        self.errorMessage = "Firebase Authentication error: \(authError.localizedDescription)"
                    } else {
                        print("✅ Successfully authenticated user: \(authResult?.user.uid ?? "Unknown")")
                    }
                }
            }
        }
    }
    
    /// Signs out the user from both Google Client and Firebase Session
    func signOut() {
        do {
            GIDSignIn.sharedInstance.signOut()
            try Auth.auth().signOut()
            self.currentUser = nil
            print("✅ Successfully signed out.")
        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
        }
    }
}
