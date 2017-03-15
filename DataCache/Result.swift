//
//  Result.swift
//  DataCache
//
//  Created by Anders Blehr on 15/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import Foundation


public enum Result<T> {
    
    case success(T)
    case failure(Error)
}
