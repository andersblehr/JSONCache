//
//  DataCacheTests.swift
//  DataCacheTests
//
//  Created by Anders Blehr on 13/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import CoreData
import XCTest
@testable import DataCache


class DataCacheTests: XCTestCase {
    
    var albums: [[String: Any]]! = nil
    var bands: [[String: Any]]! = nil
    var bandMembers: [[String: Any]]! = nil
    var musicians: [[String: Any]]! = nil
    
    
    override func setUp() {
        
        super.setUp()
        
        let filePath = Bundle.main.path(forResource: "bands", ofType: "json")
        let fileData = try! Data(contentsOf: URL(fileURLWithPath: filePath!))
        let jsonObject = try! JSONSerialization.jsonObject(with: fileData) as! [String: Any]
        
        bands = jsonObject["bands"] as! [[String: Any]]
        musicians = jsonObject["musicians"] as! [[String: Any]]
        bandMembers = jsonObject["band_members"] as! [[String: Any]]
        albums = jsonObject["albums"] as! [[String: Any]]
    }
    
    
    override func tearDown() {
        
        super.tearDown()
        
        DataCache.mainContext.reset()
    }
    
    
    func testDateConversion() {
        
        let referenceTimeInterval = 966950880.0
        let referenceDate = Date(timeIntervalSince1970: referenceTimeInterval)
        
        JSONConverter.dateFormat = .iso8601WithSeparators
        XCTAssertEqual(Date(fromJSONValue: "2000-08-22T13:28:00Z").timeIntervalSince1970, referenceTimeInterval)
        XCTAssertEqual(referenceDate.toJSONValue() as! String, "2000-08-22T13:28:00Z")
        
        JSONConverter.dateFormat = .iso8601WithoutSeparators
        XCTAssertEqual(Date(fromJSONValue: "20000822T132800Z").timeIntervalSince1970, referenceTimeInterval)
        XCTAssertEqual(referenceDate.toJSONValue() as! String, "20000822T132800Z")
        
        JSONConverter.dateFormat = .timeIntervalSince1970
        XCTAssertEqual(Date(fromJSONValue: referenceTimeInterval).timeIntervalSince1970, referenceTimeInterval)
        XCTAssertEqual(referenceDate.toJSONValue() as! TimeInterval, referenceTimeInterval)
    }
    
    
    func testStringCaseConversion() {
        
        XCTAssertEqual(JSONConverter.convert(.fromJSON, string: "snake_case_attribute"), "snakeCaseAttribute")
        XCTAssertEqual(JSONConverter.convert(.toJSON, string: "snake_case_attribute"), "snake_case_attribute")
        XCTAssertEqual(JSONConverter.convert(.fromJSON, string: "camelCaseAttribute"), "camelCaseAttribute")
        XCTAssertEqual(JSONConverter.convert(.toJSON, string: "camelCaseAttribute"), "camel_case_attribute")
        XCTAssertEqual(JSONConverter.convert(.fromJSON, string: "description", qualifier: "snakeCase"), "snakeCaseDescription")
        XCTAssertEqual(JSONConverter.convert(.fromJSON, string: "camelCaseDescription"), "camelCaseDescription")
        XCTAssertEqual(JSONConverter.convert(.toJSON, string: "camelCaseDescription"), "description")
    }
    
    
    func testDictionaryCaseConversion() {
        
        let snake_case = bands.filter({ $0["name"] as! String == "Japan" })[0]
        let camelCase = JSONConverter.convert(.fromJSON, dictionary: snake_case, qualifier: "Band")
        let snake_case_roundtrip = JSONConverter.convert(.toJSON, dictionary: camelCase)
        
        XCTAssertEqual(camelCase["bandDescription"] as! String, snake_case["description"] as! String)
        XCTAssertEqual(camelCase["bandDescription"] as! String, snake_case_roundtrip["description"] as! String)
        XCTAssertEqual(camelCase["otherNames"] as! String, snake_case["other_names"] as! String)
        XCTAssertEqual(camelCase["otherNames"] as! String, snake_case_roundtrip["other_names"] as! String)
    }
    
    
    func testJSONGeneration() {
        
        DataCache.bootstrap(withModelName: "DataCache", inMemory: true) { (result) in
            
            switch result {
            case .success:
                self.loadJSONTestData { (result) in
                    
                    switch result {
                    case .success:
                        switch DataCache.fetchObject(ofType: "Album", withId: "Stranded") {
                        case .success(let stranded):
                            XCTAssertNotNil(stranded)
                            
                            let strandedDictionary = stranded!.toJSONDictionary()
                            XCTAssertEqual(strandedDictionary["name"] as! String, "Stranded")
                            XCTAssertEqual(strandedDictionary["band"] as! String, "Roxy Music")
                            XCTAssertEqual(strandedDictionary["released"] as! String, "1973-11-01T00:00:00Z")
                        case .failure(let error):
                            XCTFail("Fetching 'Roxy Music' failed with error: \(error)")
                        }
                    case .failure(let error):
                        XCTFail("Loading JSON failed with error: \(error)")
                    }
                }
            case .failure(let error):
                XCTFail("Bootstrap failed with error: \(error)")
            }
        }
    }
    
    
    func testJSONLoading() {
        
        let expectation = self.expectation(description: "stageChanges() + applyChanges()")
        
        JSONConverter.casing = .snake_case
        JSONConverter.dateFormat = .iso8601WithSeparators
        
        DataCache.bootstrap(withModelName: "DataCache", inMemory: true) { (result) in
            
            switch result {
            case .success:
                self.loadJSONTestData { (result) in

                    switch result {
                    case .success:
                        switch DataCache.fetchObject(ofType: "Band", withId: "Roxy Music") {
                        case .success(let roxyMusic):
                            XCTAssertNotNil(roxyMusic)
                            XCTAssertEqual((roxyMusic as! Band).formed, 1971)
                            XCTAssertEqual((roxyMusic as! Band).members!.count, 7)
                            XCTAssertEqual((roxyMusic as! Band).albums!.count, 10)
                            
                            expectation.fulfill()
                        case .failure(let error):
                            XCTFail("Fetching 'Roxy Music' failed with error: \(error)")
                        }
                    case .failure(let error):
                        XCTFail("Loading JSON failed with error: \(error)")
                    }
                }
            case .failure(let error):
                XCTFail("Bootstrap failed with error: \(error)")
            }
        }
        
        self.waitForExpectations(timeout: 5.0)
    }
    
    
    func testJSONMerging() {
        
        let expectation = self.expectation(description: "stageChanges() + applyChanges()")
        
        DataCache.bootstrap(withModelName: "DataCache", inMemory: true) { (result: Result) in

            switch result {
            case .success:
                self.loadJSONTestData { (result) in
                    
                    switch result {
                    case .success:
                        let assemblageDictionary = ["name": "Assemblage", "band": "Japan", "released": "1981-09-01T00:00:00Z", "label": "Hansa"]
                        
                        DataCache.stageChanges(withDictionary: assemblageDictionary, forEntityWithName: "Album")
                        DataCache.applyChanges { (result) in
                            switch result {
                            case .success:
                                switch DataCache.fetchObject(ofType: "Album", withId: "Assemblage") {
                                case .success(let assemblage):
                                    XCTAssertNotNil(assemblage)
                                    XCTAssertEqual((assemblage as! Album).name, "Assemblage")
                                    XCTAssertEqual((assemblage as! Album).band!.name, "Japan")
                                    XCTAssertEqual((assemblage as! Album).band!.albums!.count, 8)
                                    
                                    expectation.fulfill()
                                case .failure(let error):
                                    XCTFail("Fetching 'Assemblage' failed with error \(error)")
                                }
                            case .failure(let error):
                                XCTFail("Loading 'Assemblage' JSON failed with error: \(error)")
                            }
                        }
                    case .failure(let error):
                        XCTFail("Loading JSON failed with error: \(error)")
                    }
                }
            case .failure(let error):
                XCTFail("Bootstrap failed with error: \(error)")
            }
        }
        
        self.waitForExpectations(timeout: 5.0)
    }
    
    
    func testFetchByIds() {

        DataCache.bootstrap(withModelName: "DataCache", inMemory: true) { (result) in
            
            switch result {
            case .success:
                self.loadJSONTestData { (result) in
                    
                    switch result {
                    case .success:
                        switch DataCache.fetchObjects(ofType: "Musician", withIds: ["Bryan Ferry", "Brian Eno", "David Sylvian", "Mick Karn", "Phil Manzanera", "Steve Jansen"]) {
                        case .success(let musicians):
                            XCTAssertNotNil(musicians.filter({ ($0 as! Musician).name == "Bryan Ferry" }).count == 1)
                            XCTAssertNotNil(musicians.filter({ ($0 as! Musician).name == "Brian Eno" }).count == 1)
                            XCTAssertNotNil(musicians.filter({ ($0 as! Musician).name == "David Sylvian" }).count == 1)
                            XCTAssertNotNil(musicians.filter({ ($0 as! Musician).name == "Bryan Mick Karn" }).count == 1)
                            XCTAssertNotNil(musicians.filter({ ($0 as! Musician).name == "Phil Manzanera" }).count == 1)
                            XCTAssertNotNil(musicians.filter({ ($0 as! Musician).name == "Steve Jansen" }).count == 1)
                        case .failure(let error):
                            XCTFail("Fetching musicians failed with error: \(error)")
                        }
                    case .failure(let error):
                        XCTFail("Loading JSON failed with error: \(error)")
                    }
                }
            case .failure(let error):
                XCTFail("Bootstrap failed with error: \(error)")
            }
        }
    }
    
    
    func testFailureScenarios() {
    
        DataCache.bootstrap(withModelName: "NoModel") { (result) in
            
            switch result {
            case .success:
                XCTFail("Bootstrapping non-existing model succeeded. This should not happen.")
            case .failure(let error):
                switch error as! BootstrapError {
                case .modelNotFound:
                    break
                default:
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }
    }
    
    
    // MARK: - Shared methods
    
    func loadJSONTestData(completion: @escaping (_ result: Result<Void>) -> Void) {
        
        DataCache.stageChanges(withDictionaries: self.bands, forEntityWithName: "Band")
        DataCache.stageChanges(withDictionaries: self.musicians, forEntityWithName: "Musician")
        DataCache.stageChanges(withDictionaries: self.bandMembers, forEntityWithName: "BandMember")
        DataCache.stageChanges(withDictionaries: self.albums, forEntityWithName: "Album")
        DataCache.applyChanges { (result) in
            
            switch result {
            case .success:
                DispatchQueue.main.async { completion(Result.success()) }
            case .failure(let error):
                DispatchQueue.main.async { completion(Result.failure(error)) }
            }
        }
    }
}
