//
//  JSONCache.swift
//  JSONCache
//
//  Created by Anders Blehr on 07/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import CoreData
import Foundation

import Result


/// Enum describing the set of errors that may be returned by JSONCache methods
public enum JSONCacheError: Error {
    /// A managed object model with the wrapped file name could not be found.
    case modelNotFound(String)
    /// The managed object model could not be initialized with the wrapped URL.
    case modelInitializationError(URL)
    /// The `mainContext` is `nil`, either because boostrapping has not completed,
    /// or because it has not been initiated.
    case managedObjectContextNotAvailable
    /// There is no entity with the wrapped name.
    case noSuchEntity(String)
    /// The wrapped error ocurred during a Core Data operation.
    case coreDataError(Error)
}

/// JSONCache is a thin layer on top of Core Data that seamlessly consumes, caches
/// and produces JSON data.
///
/// - Automatically creates Core Data objects from JSON data, or merges JSON data
///   into objects that already exist.
/// - Automatically maps 1:1 and 1:N relationships based on inferred knowledge of
///   your Core Data model.
/// - If necessary, automatically maps between `snake_case` in JSON and `camelCase`
///   in Core Data attribute names.
/// - Generates JSON on demand, both from `NSManagedObject` instances, and from
///   any `struct` that adopts the `JSONifiable` protocol.
/// - Operates on background threads to avoid interfering with your app's
///   responsiveness.
/// - Both synchronous and asynchronous methods return instances of 
///  [Result](https://github.com/antitypical/Result), the go-to implementation for
///  Swift of a functional pattern that puts emphasis on the semantics of success
///  or failure.

public struct JSONCache {
    
    /// Enum defining the JSON casing conventions supported by JSONCache.
    public enum Casing {
        /// Indicates that JSON data is `camelCase`d.
        case camelCase
        /// Indicates that JSON data is `snake_case`d.
        case snake_case
    }
    
    /// Enum defining the JSON date formats supported by JSONCache
    public enum DateFormat {
        /// Indicates that dates in JSON data are represented as ISO 8601 date
        /// strings with separators: `2000-08-22T13:28:00Z`
        case iso8601WithSeparators
        /// Indicates that dates in JSON data are represented as ISO 8601 date
        /// strings without separators: `20000822T132800Z`
        case iso8601WithoutSeparators
        /// Indicates that dates in JSON data are represented as double precision
        /// value containing the number of seconds since 00:00 on 1 Jan 1970.
        case timeIntervalSince1970
    }
    
    /// Defines the casing convention used in consumed and/or produced JSON data.
    public static var casing: Casing = .camelCase
    /// Defines the date format used in consumed and/or produced JSON data.
    public static var dateFormat: DateFormat = .iso8601WithSeparators
    /// The managed object context associated with the main queue.
    public static var mainContext: NSManagedObjectContext! = nil
    
    
    // MARK: - Bootstrapping the Core Data stack
    
    /// Boostrap the Core Data stack. Must be called before invoking any other
    /// methods.
    ///
    /// - Parameters:
    ///   - modelName: The name of the managed object model to use.
    ///   - inMemory: `true` if the persistent store should be in memory only.
    ///     Defaults to `false` if not given, in which case the persistent store
    ///     is of SQLLite type.
    ///   - bundle: The `Bundle` instance to use to look up the managed object
    ///     model. Defaults to `Bundle.main` if not given.
    ///   - completion: A closure to be executed when bootstrapping is complete.
    ///   - result: A `Result<Void, JSONCacheError>` instance passed to the
    ///     completion closure that should be inspected to determine if
    ///     bootstrapping completed successfully.
    
    public static func bootstrap(withModelName modelName: String, inMemory: Bool = false, bundle: Bundle = .main, completion: @escaping (_ result: Result<Void, JSONCacheError>) -> Void) {
        
        guard mainContext == nil || modelName != mainContext.name else {
            DispatchQueue.main.async { completion(Result.success()) }
            return
        }
        
        let persistentStoreType = inMemory ? NSInMemoryStoreType : NSSQLiteStoreType
        
        guard let managedObjectModelURL = bundle.url(forResource: modelName, withExtension: "momd") else {
            DispatchQueue.main.async { completion(Result.failure(JSONCacheError.modelNotFound(modelName))) }
            return
        }
        
        guard let managedObjectModel = NSManagedObjectModel(contentsOf: managedObjectModelURL) else {
            DispatchQueue.main.async { completion(Result.failure(JSONCacheError.modelInitializationError(managedObjectModelURL))) }
            return
        }
        
        if #available(OSX 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
            let persistentStoreDescription = NSPersistentStoreDescription()
            persistentStoreDescription.type = persistentStoreType
            
            let persistentContainer = NSPersistentContainer(name: modelName, managedObjectModel: managedObjectModel)
            persistentContainer.persistentStoreDescriptions = [persistentStoreDescription]
            persistentContainer.loadPersistentStores { (_, error) in
                
                guard error == nil else {
                    DispatchQueue.main.async { completion(Result.failure(JSONCacheError.coreDataError(error!))) }
                    return
                }
                
                mainContext = persistentContainer.viewContext
                mainContext.name = modelName
                
                DispatchQueue.main.async { completion(Result.success()) }
            }
        } else {
            let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
            let libraryDirectoryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).last!
            let persistentStoreURL = libraryDirectoryURL.appendingPathComponent("\(modelName).sqlite")
            
            do {
                try persistentStoreCoordinator.addPersistentStore(ofType: persistentStoreType, configurationName: nil, at: persistentStoreURL, options: [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true])
                
                mainContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
                mainContext.persistentStoreCoordinator = persistentStoreCoordinator
                mainContext.name = modelName
                
                DispatchQueue.main.async { completion(Result.success()) }
            } catch {
                DispatchQueue.main.async { completion(Result.failure(JSONCacheError.coreDataError(error))) }
            }
        }
    }
    
    
    // MARK: - Loading JSON dictionaries into Core Data
    
    /// Stage a JSON dictionary for loading into Core Data.
    ///
    /// - Parameters:
    ///   - dictionary: The JSON dictionary to load into Core Data.
    ///   - entityName: The name of the Core Data entity that will hold the
    ///     dictionary data.
    
    public static func stageChanges(withDictionary dictionary: [String: Any], forEntityWithName entityName: String) {
        
        stageChanges(withDictionaries: [dictionary], forEntityWithName: entityName)
    }
    
    
    /// Stage an array JSON dictionaries for loading into Core Data.
    ///
    /// - Parameters:
    ///   - dictionaries: The array of JSON dictionaries to load into Core Data.
    ///   - entityName: The name of the Core Data entity that will hold the
    ///     dictionary data.
    
    public static func stageChanges(withDictionaries dictionaries: [[String: Any]], forEntityWithName entityName: String) {
        
        var stagedDictionaries = [[String: Any]]()
        for dictionary in dictionaries {
            stagedDictionaries.append(JSONConverter.convert(.fromJSON, dictionary: dictionary, qualifier: entityName))
        }
        
        stagedDictionariesByEntityName[entityName] = stagedDictionaries
    }
    
    
    /// Load the staged JSON dictionaries into Core Data on a background thread.
    ///
    /// - Parameters:
    ///   - completion: A closure to be executed when loading has completed.
    ///   - result: A `Result<Void, JSONCacheError>` instance passed to the
    ///     completion closure that should be inspected to determine if the
    ///     dictionaries were successfully loaded into Core Data.
    
    public static func applyChanges(completion: @escaping (_ result: Result<Void, JSONCacheError>) -> Void) {
        
        guard mainContext != nil else {
            DispatchQueue.main.async { completion(Result.failure(JSONCacheError.managedObjectContextNotAvailable)) }
            return
        }
        
        let backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundContext.parent = mainContext
        backgroundContext.perform {
            
            for (entityName, dictionaries) in stagedDictionariesByEntityName {
                for dictionary in dictionaries {
                    let identifierName = NSEntityDescription.entity(forEntityName: entityName, in: backgroundContext)!.identifierName!
                    let objectId = dictionary[identifierName] as! AnyHashable
                    
                    switch fetchObject(ofType: entityName, withId: objectId, in: backgroundContext) {
                    case .success(var object):
                        if object == nil {
                            object = NSEntityDescription.insertNewObject(forEntityName: entityName, into: backgroundContext)
                            objectsByEntityAndId["\(entityName).\(objectId)"] = object
                            dictionariesByEntityAndId["\(entityName).\(objectId)"] = dictionary
                        }
                        
                        object!.setAttributes(fromDictionary: dictionary)
                    case .failure(let error):
                        DispatchQueue.main.async { completion(Result.failure(error)) }
                    }
                }
            }
            
            for (objectEntityAndId, object) in objectsByEntityAndId {
                for (relationshipName, relationship) in object.entity.relationshipsByName {
                    if !relationship.isToMany {
                        let dictionary = dictionariesByEntityAndId[objectEntityAndId]!
                        let destinationId = dictionary[relationshipName] as! AnyHashable
                        let destinationEntityName = relationship.destinationEntity!.name!
                        
                        if let destinationObject = objectsByEntityAndId["\(destinationEntityName).\(destinationId)"] {
                            object.setValue(destinationObject, forKey: relationshipName)
                        } else {
                            switch fetchObject(ofType: destinationEntityName, withId: destinationId, in: backgroundContext) {
                            case .success(let destinationObject):
                                if let destinationObject = destinationObject {
                                    object.setValue(destinationObject, forKey: relationshipName)
                                }
                            case .failure(let error):
                                DispatchQueue.main.async { completion(Result.failure(error)) }
                            }
                        }
                    }
                }
            }
            
            switch save(context: backgroundContext) {
            case .success:
                mainContext.performAndWait {
                    switch save() {
                    case .success:
                        DispatchQueue.main.async { completion(Result.success()) }
                    case .failure(let error):
                        DispatchQueue.main.async { completion(Result.failure(error)) }
                    }
                    
                    stagedDictionariesByEntityName.removeAll()
                    dictionariesByEntityAndId.removeAll()
                    objectsByEntityAndId.removeAll()
                }
            case .failure(let error):
                DispatchQueue.main.async { completion(Result.failure(error)) }
            }
        }
    }
    
    
    // MARK: - Core Data interaction
    
    /// Save any changes in the parent store of the given managed object context.
    /// Roll back the save operation if an error occurs.
    ///
    /// - Parameters:
    ///   - context: The managed object context whose parent store should be
    ///     saved. Defaults to `mainContext` if not given.
    /// - Returns: A `Result<Void, JSONCacheError>` instance that should be
    ///   inspected to determine if the save operation completed successfully.
    
    public static func save(context: NSManagedObjectContext = mainContext) -> Result<Void, JSONCacheError> {
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                context.rollback()
                return Result.failure(JSONCacheError.coreDataError(error))
            }
        }
        
        return Result.success()
    }
    
    /// Fetch a managed object from the persistent store.
    ///
    /// - Parameters:
    ///   - entityName: The entity name of the object to be fetched.
    ///   - identifier: The primary key value of the object. The entity's primary
    ///     key is either an attribute with name `id`, or an attribute with the
    ///     User Info key `JC.isIdentifier` set to `true` or `YES`.
    ///   - context: The managed object context from which to fetch the object.
    ///     Defaults to `mainContext` if not given.
    /// - Returns: A `Result<NSManagedObject?, JSONCacheError>` instance from which
    ///   the fetched object can be retrieved if the fetch operation completed
    ///   successfully.
    
    public static func fetchObject<ResultType: NSManagedObject>(ofType entityName: String, withId identifier: AnyHashable, in context: NSManagedObjectContext? = mainContext) -> Result<ResultType?, JSONCacheError> {
        
        guard context != nil else {
            return Result.failure(JSONCacheError.managedObjectContextNotAvailable)
        }
        
        if let entity = NSEntityDescription.entity(forEntityName: entityName, in: context!) {
            let fetchRequest = NSFetchRequest<ResultType>(entityName: entityName)
            fetchRequest.predicate = NSPredicate(format: "%K == %@", entity.identifierName!, identifier as CVarArg)
            
            do {
                let object = try context!.fetch(fetchRequest).first
                return Result.success(object)
            } catch {
                return Result.failure(JSONCacheError.coreDataError(error))
            }
        } else {
            return Result.failure(JSONCacheError.noSuchEntity(entityName))
        }
    }
    
    
    /// Fetch an array of managed objects from the persistent store.
    /// 
    /// - Parameters:
    ///   - entityName: The entity name of the objects to be fetched.
    ///   - identifiers: An array containing the primary key values of the objects.
    ///     The entity's primary key is either an attribute with name `id`, or an
    ///     attribute with the User Info key `JC.isIdentifier` set to `true` or `YES`.
    ///   - context: The managed object context from which to fetch the objects.
    ///     Defaults to `mainContext` if not given.
    /// - Returns: A `Result<[NSManagedObject], JSONCacheError>` instance from which
    ///   the fetched objects can be retrieved if the fetch operation completed
    ///   successfully.
    
    public static func fetchObjects<ResultType: NSManagedObject>(ofType entityName: String, withIds identifiers: [AnyHashable], in context: NSManagedObjectContext? = mainContext) -> Result<[ResultType], JSONCacheError> {
        
        guard context != nil else {
            return Result.failure(JSONCacheError.managedObjectContextNotAvailable)
        }
        
        if let entity = NSEntityDescription.entity(forEntityName: entityName, in: context!) {
            let fetchRequest = NSFetchRequest<ResultType>(entityName: entityName)
            fetchRequest.predicate = NSPredicate(format: "%K IN %@", entity.identifierName!, identifiers)
            
            do {
                let objects = try context!.fetch(fetchRequest)
                return Result.success(objects)
            } catch {
                return Result.failure(JSONCacheError.coreDataError(error))
            }
        } else {
            return Result.failure(JSONCacheError.noSuchEntity(entityName))
        }
    }
    
    
    // MARK: - Private implementation details
    
    private static var stagedDictionariesByEntityName = [String: [[String: Any]]]()
    private static var dictionariesByEntityAndId = [AnyHashable: [String: Any]]()
    private static var objectsByEntityAndId = [AnyHashable: NSManagedObject]()
    
    
    private init() {  }
}
