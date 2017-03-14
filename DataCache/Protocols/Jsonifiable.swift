//
//  Jsonifiable.swift
//  DataCache
//
//  Created by Anders Blehr on 12/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import Foundation


protocol Jsonifiable {
    
    func toJSONDictionary() -> [String: Any]
}


extension Jsonifiable {
    
    func toJSONDictionary() -> [String: Any] {
        
        var dictionary = [String: Any]()
        let isStruct = !(type(of:self) is AnyClass)
        
        if isStruct {
            for case let (label?, value) in Mirror(reflecting: self).children {
                let stringValue = "\(value)"
                
                if stringValue != "nil" && stringValue != ""  {
                    dictionary[label] = value
                }
            }
        }
        
        return JSONConverter.convert(.toJSON, dictionary: dictionary)
    }
}
