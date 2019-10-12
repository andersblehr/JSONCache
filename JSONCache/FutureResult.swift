//
//  FutureResult.swift
//  JSONCache
//
//  Created by Anders Blehr on 12/10/2019.
//  Copyright © 2019 Anders Blehr. All rights reserved.
//

import Foundation

public class FutureResult<T, E: Error> {
    fileprivate var result: Result<T, E>? {
        didSet { observers.forEach { observer in result.map(observer) } }
    }
    fileprivate lazy var observers = [(Result<T, E>) -> Void]()
    
    func observe(with observer: @escaping (Result<T, E>) -> Void) {
        observers.append(observer)
        result.map(observer)
    }
    
    func map<U>(_ f: @escaping (T) throws -> Result<U, E>) -> FutureResult<U, E> {
        return flatMap { value in
            try FutureResult<U, E>(f(value))
        }
    }
    
    func flatMap<U>(_ f: @escaping (T) throws -> FutureResult<U, E>) -> FutureResult<U, E> {
        let futureResult = FutureResult<U, E>()
        observe { result in
            switch result {
            case .success(let value):
                do {
                    try f(value).observe { result in
                        futureResult.resolve(result: result)
                    }
                } catch {
                    futureResult.resolve(result: .failure(error as! E))
                }
            case .failure(let error):
                futureResult.resolve(result: .failure(error))
            }
        }
        
        return futureResult
    }
    
    func resolve(result: Result<T, E>) {
        self.result = result
    }

    static func unit(value: T) -> FutureResult<T, E> {
        return FutureResult(.success(value))
    }
    
    fileprivate convenience init(_ result: Result<T, E>) {
        self.init()
        self.result = result;
    }
}
