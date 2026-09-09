//
//  New_Cold_FusionApp.swift
//  New Cold Fusion
//
//  Created by David Nishimoto on 9/8/26.
//

import SwiftUI
import CoreData

@main
struct New_Cold_FusionApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
