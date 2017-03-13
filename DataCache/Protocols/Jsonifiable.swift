//
//  Jsonifiable.swift
//  DataCache
//
//  Created by Anders Blehr on 12/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import Foundation


protocol Jsonifiable {
    
    func toDictionary(withCasing casing: CamelSnake.Casing) -> [String: Any]
}


extension Jsonifiable {
    
    func toDictionary(withCasing casing: CamelSnake.Casing = .snake_case) -> [String: Any] {
        
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
        
        return casing == .camelCase ? dictionary : CamelSnake.convert(dictionary: dictionary, toCase: .snake_case)
    }
}
