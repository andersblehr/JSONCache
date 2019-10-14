//
//  ResultPromise.swift
//  JSONCache
//
//  Created by Anders Blehr on 12/10/2019.
//  Copyright © 2019 Anders Blehr. All rights reserved.
//

import Foundation

/**
 `ResultPromise` is a minimal `Promise` implementation that wraps a
 `Result<T, E>` instance. It supports the `fulfil`, `await`, `then` and
 `thenAsync` combinators, facilitating a fluid sequencing of computations that
 produce either a `Result` (`then`) or a `ResultPromise` instance (`thenAsync`).
 (The `reject` combinator is redundant, as failure is handled by the embedded
 `Result`.)
 */
public class ResultPromise<T, E: Error> {
    fileprivate var result: Result<T, E>? {
        didSet { observers.forEach { observer in result.map(observer) } }
    }
    fileprivate lazy var observers = [(Result<T, E>) -> Void]()
    
    /// Fulfil this promise with `result`.
    ///
    /// - Parameters:
    ///   - result: A `Result<T, E>` that describes the result.
    public func fulfil(with result: Result<T, E>) {
        self.result = result
    }
    
    /**
     Execute the `observer` closure when the promise is fulfilled.
    
     - Parameters:
       - observer: A closure that takes a `Result` instance and returns
         nothing.
     */
    public func await(with observer: @escaping (Result<T, E>) -> Void) {
        observers.append(observer)
        result.map(observer)
    }
    
    /**
     Produce a new `ResultPromise` by `flatMap`'ing the supplied function over
     the embedded `Result`.
    
     - Parameters:
        - f: A closure `(T) -> Result<U, E>`.
     - Returns: A new `ResultPromise<U, E>` instance, where the embedded
       `Result<U, E>` is the result of `flatMap`'ing `f` over the
       `Result<T, E>` embedded in this instance.
     */
    public func then<U>(_ f: (@escaping (T) -> Result<U, E>)) -> ResultPromise<U, E> {
        let promise = ResultPromise<U, E>()
        await { result in
            promise.fulfil(with: result.flatMap(f))
        }
        
        return promise
    }
    
    /**
     Produce a new `ResultPromise` by applying the supplied function to the
     value contained in the embedded `Result` instance.
    
     - Parameters:
        - f: A closure `(T) -> Result<U, E>`.
     - Returns: A new `ResultPromise<U, E>` instance.
     */
    public func thenAsync<U>(_ f: (@escaping (T) -> ResultPromise<U, E>)) -> ResultPromise<U, E> {
        let promise = ResultPromise<U, E>()
        await { result in
            switch result {
            case .success(let value):
                f(value).await { result in
                    promise.fulfil(with: result)
                }
            case .failure(let error):
                promise.fulfil(with: .failure(error))
            }
        }
        
        return promise
    }
}
