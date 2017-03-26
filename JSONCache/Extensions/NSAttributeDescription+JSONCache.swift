//
//  NSAttributeDescription+JSONCache.swift
//  JSONCache
//
//  Created by Anders Blehr on 12/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import CoreData
import Foundation


public extension NSAttributeDescription {
    
    /// `true` if this attribute is the identifier (primary key) of the entity
    /// to which it belongs; `false` otherwise.
    public var isIdentifier: Bool {
        
        if let identifierFlag = self.userInfo!["JC.isIdentifier"] as? String {
            return ["true", "yes"].contains(identifierFlag.lowercased())
        }
        
        return false
    }
}
