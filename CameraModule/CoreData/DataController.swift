//
//  DataController.swift
//  CameraModule
//
//  Created by Trevor Welsh on 9/2/22.
//

import CoreData
import Foundation

class DataController: ObservableObject {
    public let container = NSPersistentContainer(name: "MediaGallery")

    init() {
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error)")
            }
        }
    }
}
