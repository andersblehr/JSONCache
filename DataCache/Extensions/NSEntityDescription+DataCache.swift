//
//  NSEntityDescription+DataCache.swift
//  DataCache
//
//  Created by Anders Blehr on 10/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import CoreData
import Foundation


internal extension NSEntityDescription {

    internal var identifierName: String? {
        get {
            for (attributeName, attribute) in self.attributesByName {
                if attributeName == "id" || attribute.isIdentifier {
                    return attributeName
                }
            }
            
            return nil
        }
    }
}
