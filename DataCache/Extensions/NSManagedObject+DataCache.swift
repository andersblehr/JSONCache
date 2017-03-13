//
//  NSManagedObject+DataCache.swift
//
//  Created by Anders Blehr on 10/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import CoreData
import Foundation


extension NSManagedObject: Jsonifiable {
    
    internal var identifier: AnyHashable? {
        get {
            if let identifierName = self.entity.identifierName {
                return self.value(forKey: identifierName) as? AnyHashable
            }
            
            return nil
        }
    }
    
    
    internal func setAttributes(fromDictionary dictionary: [String: Any]) {
        
        for (attributeName, attribute) in self.entity.attributesByName {
            if let value = dictionary[attributeName] {
                if attribute.attributeType == .dateAttributeType {
                    self.setValue(DateFormatter.dateTime(from: value as! String), forKey: attributeName)
                } else {
                    self.setValue(value, forKey: attributeName)
                }
            }
        }
    }
    
    
    // MARK: - Jsonifiable conformance
    
    internal func toDictionary(withCasing casing: CamelSnake.Casing = .snake_case) -> [String: Any] {
        
        var dictionary = [String: Any]()
        
        for (attributeName, _) in self.entity.attributesByName {
            if let value = self.value(forKey: attributeName) {
                dictionary[attributeName] = value
            }
        }
        
        for (relationshipName, relationship) in self.entity.relationshipsByName {
            if !relationship.isToMany {
                if let destinationObject = self.value(forKey: relationshipName) as? NSManagedObject {
                    if destinationObject.entity.attributesByName.keys.contains("id") {
                        dictionary[relationshipName] = destinationObject.value(forKey: "id")
                    } else {
                        for (destinationAttributeName, destinationAttribute) in destinationObject.entity.attributesByName {
                            if destinationAttribute.isIdentifier {
                                dictionary[relationshipName] = destinationObject.value(forKey: destinationAttributeName)
                            }
                        }
                    }
                }
            }
        }
        
        return casing == .camelCase ? dictionary : CamelSnake.convert(dictionary: dictionary, toCase: .snake_case)
    }
}
