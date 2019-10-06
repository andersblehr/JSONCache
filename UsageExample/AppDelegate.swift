//
//  AppDelegate.swift
//  JSONCache
//
//  Created by Anders Blehr on 13/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import UIKit
import CoreData

import JSONCache


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        return true
    }
    
    
    func applicationWillTerminate(_ application: UIApplication) {
        
        switch JSONCache.save() {
        case .success:
            break
        case .failure(let error):
            print("Error saving context: \(error)")
        }
    }
}
