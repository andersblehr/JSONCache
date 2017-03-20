//
//  JSONCache.swift
//  JSONCache
//
//  Created by Anders Blehr on 07/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import CoreData
import Foundation


public enum JSONCacheError: Error {
    case unsupportedPersistentStoreType(String)
    case modelNotFound(String)
    case modelInitializationError(URL)
    case managedObjectContextNotAvailable
    case noSuchEntity(String)
}

public enum Result<T> {
    case success(T)
    case failure(Error)
}


public struct JSONCache {
    
    public enum Casing {
        case camelCase
        case snake_case
    }
    
    public enum DateFormat {
        case iso8601WithSeparators
        case iso8601WithoutSeparators
        case timeIntervalSince1970
    }
    
    public static var casing: Casing = .camelCase
    public static var dateFormat: DateFormat = .iso8601WithSeparators
    public static var mainContext: NSManagedObjectContext! = nil
    
    
    // MARK: - Bootstrapping the Core Data stack
    
    public static func bootstrap(withModelName modelName: String, inMemory: Bool = false, bundle: Bundle = Bundle.main, completion: @escaping (_ result: Result<Void>) -> Void) {
        
        let persistentStoreType = inMemory ? NSInMemoryStoreType : NSSQLiteStoreType
        
        guard let managedObjectModelURL = bundle.url(forResource: modelName, withExtension: "momd") else {
            DispatchQueue.main.async { completion(Result.failure(JSONCacheError.modelNotFound(modelName))) }
            return
        }
        
        guard let managedObjectModel = NSManagedObjectModel(contentsOf: managedObjectModelURL) else {
            DispatchQueue.main.async { completion(Result.failure(JSONCacheError.modelInitializationError(managedObjectModelURL))) }
            return
        }
        
        if #available(OSX 10.12, iOS 10.0, tvOS 10.0, *) {
            let persistentStoreDescription = NSPersistentStoreDescription()
            persistentStoreDescription.type = persistentStoreType
            
            let persistentContainer = NSPersistentContainer(name: modelName, managedObjectModel: managedObjectModel)
            persistentContainer.persistentStoreDescriptions = [persistentStoreDescription]
            persistentContainer.loadPersistentStores { (_, error) in
                
                guard error == nil else {
                    DispatchQueue.main.async { completion(Result.failure(error!)) }
                    return
                }
                
                mainContext = persistentContainer.viewContext
                
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
                
                DispatchQueue.main.async { completion(Result.success()) }
            } catch {
                DispatchQueue.main.async { completion(Result.failure(error)) }
            }
        }
    }
    
    
    // MARK: - Loading JSON dictionaries into Core Data
    
    public static func stageChanges(withDictionary dictionary: [String: Any], forEntityWithName entityName: String) {
        
        stageChanges(withDictionaries: [dictionary], forEntityWithName: entityName)
    }
    
    
    public static func stageChanges(withDictionaries dictionaries: [[String: Any]], forEntityWithName entityName: String) {
        
        var stagedDictionaries = [[String: Any]]()
        for dictionary in dictionaries {
            stagedDictionaries.append(JSONConverter.convert(.fromJSON, dictionary: dictionary, qualifier: entityName))
        }
        
        stagedDictionariesByEntityName[entityName] = stagedDictionaries
    }
    
    
    public static func applyChanges(completion: @escaping (_ result: Result<Void>) -> Void) {
        
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
    
    public static func save(context: NSManagedObjectContext = mainContext) -> Result<Void> {
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                context.rollback()
                return Result.failure(error)
            }
        }
        
        return Result.success()
    }
    
    
    public static func fetchObject<ResultType: NSManagedObject>(ofType entityName: String, withId identifier: AnyHashable, in context: NSManagedObjectContext? = mainContext) -> Result<ResultType?> {
        
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
                return Result.failure(error)
            }
        } else {
            return Result.failure(JSONCacheError.noSuchEntity(entityName))
        }
    }
    
    
    public static func fetchObjects<ResultType: NSManagedObject>(ofType entityName: String, withIds identifiers: [AnyHashable], in context: NSManagedObjectContext? = mainContext) -> Result<[ResultType]> {
        
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
                return Result.failure(error)
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
