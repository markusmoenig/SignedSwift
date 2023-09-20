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
    let model = Model()
    
    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
