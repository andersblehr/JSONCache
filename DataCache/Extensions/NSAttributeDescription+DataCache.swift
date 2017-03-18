//
//  NSAttributeDescription+DataCache.swift
//  DataCache
//
//  Created by Anders Blehr on 12/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import CoreData
import Foundation


public extension NSAttributeDescription {
    
    public var isIdentifier: Bool {
        
        if let identifierFlag = self.userInfo!["DC.isIdentifier"] as? String {
            return ["true", "yes"].contains(identifierFlag.lowercased())
        }
        
        return false
    }
}
