//
//  CameraModuleApp.swift
//  CameraModule
//
//  Created by Trevor Welsh on 9/2/22.
//

import SwiftUI

@main
struct CameraModuleApp: App {
    @StateObject var dataController = DataController()
    let cvm = CameraViewModel()
    var body: some Scene {
        WindowGroup {
            CameraView()
                .environment(\.managedObjectContext, dataController.container.viewContext)
                .environmentObject(cvm)
        }
    }
}
