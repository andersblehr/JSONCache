//
//  JSONifiable.swift
//  JSONCache
//
//  Created by Anders Blehr on 12/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import Foundation


public protocol JSONifiable {
    
    func toJSONDictionary() -> [String: Any]
}


public extension JSONifiable {
    
    public func toJSONDictionary() -> [String: Any] {
        
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
