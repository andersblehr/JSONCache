//
//  NSEntityDescription+JSONCache.swift
//  JSONCache
//
//  Created by Anders Blehr on 10/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import CoreData
import Foundation


public extension NSEntityDescription {
    
    /// The name of the identifier (primary key) attribute of this entity.
    var identifierName: String? {
        
        for (attributeName, attribute) in self.attributesByName {
            if attributeName == "id" || attribute.isIdentifier {
                return attributeName
            }
        }
        
        return nil
    }
}
