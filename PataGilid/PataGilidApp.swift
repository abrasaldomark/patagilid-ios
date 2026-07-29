//
//  PataGilidApp.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/27/26.
//

import SwiftUI
import FirebaseCore
import GoogleMaps
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Initialize Firebase services
        FirebaseApp.configure()

        // Securely initialize Google Maps & Google Sign-In using credentials loaded from GoogleService-Info.plist
        if let apiKey = FirebaseApp.app()?.options.apiKey {
            GMSServices.provideAPIKey(apiKey)
        }

        if let clientID = FirebaseApp.app()?.options.clientID {
            let configuration = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = configuration
            GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                if let user = user {
                    print("🔄 [AppDelegate] Restored active Google session for: \(user.profile?.email ?? "User")")
                }
            }
        }

        return true
    }

    // Handle URL callbacks for Google Sign-In authentication flows
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

@main
struct PataGilidApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
