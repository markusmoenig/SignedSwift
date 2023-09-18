//
//  SignedApp.swift
//  Signed
//
//  Created by Markus Moenig on 18/9/23.
//

import SwiftUI

@main
struct SignedApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
