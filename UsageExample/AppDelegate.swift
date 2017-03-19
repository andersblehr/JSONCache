//
//  AppDelegate.swift
//  DataCache
//
//  Created by Anders Blehr on 13/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import UIKit
import CoreData

import DataCache


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        return true
    }
    
    
    func applicationWillTerminate(_ application: UIApplication) {
        
        switch DataCache.save() {
        case .success:
            break
        case .failure(let error):
            print("Error saving context: \(error)")
        }
    }
}
