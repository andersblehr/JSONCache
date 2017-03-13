//
//  NSAttributeDescription+DataCache.swift
//  DataCache
//
//  Created by Anders Blehr on 12/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import CoreData
import Foundation


internal extension NSAttributeDescription {
    
    internal var isIdentifier: Bool {
        get {
            if let identifierFlag = self.userInfo!["DC.isIdentifier"] as? String {
                return ["true", "yes"].contains(identifierFlag.lowercased())
            }
            
            return false
        }
    }
}
