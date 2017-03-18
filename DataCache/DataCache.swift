//
//  DataCache.swift
//  DataCache
//
//  Created by Anders Blehr on 07/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import CoreData
import Foundation


public enum BootstrapError: Error {
    case unsupportedPersistentStoreType(String)
    case modelNotFound(String)
    case modelInitializationError(URL)
    case managedObjectContextNotAvailable
}

public enum Result<T> {
    case success(T)
    case failure(Error)
}


public struct DataCache {
    
    public static var mainContext: NSManagedObjectContext! = nil
    
    
    // MARK: - Bootstrapping the Core Data stack
    
    public static func bootstrap(withModelName modelName: String, inMemory: Bool = false, completion: @escaping (_ result: Result<Void>) -> Void) {

        let persistentStoreType = inMemory ? NSInMemoryStoreType : NSSQLiteStoreType
        
        if #available(iOS 10.0, *) {
            let persistentStoreDescription = NSPersistentStoreDescription()
            persistentStoreDescription.type = persistentStoreType
            
            let persistentContainer = NSPersistentContainer(name: modelName)
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
            guard [NSSQLiteStoreType, NSInMemoryStoreType].contains(persistentStoreType) else {
                DispatchQueue.main.async { completion(Result.failure(BootstrapError.unsupportedPersistentStoreType(persistentStoreType))) }
                return
            }
            
            guard let managedObjectModelURL = Bundle.main.url(forResource: modelName, withExtension: "momd") else {
                DispatchQueue.main.async { completion(Result.failure(BootstrapError.modelNotFound(modelName))) }
                return
            }
            
            guard let managedObjectModel = NSManagedObjectModel(contentsOf: managedObjectModelURL) else {
                DispatchQueue.main.async { completion(Result.failure(BootstrapError.modelInitializationError(managedObjectModelURL))) }
                return
            }
            
            let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
            let documentDirectoryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).last!
            let persistentStoreURL = documentDirectoryURL.appendingPathComponent("\(modelName).sqlite")
            
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
            DispatchQueue.main.async { completion(Result.failure(BootstrapError.managedObjectContextNotAvailable)) }
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
            return Result.failure(BootstrapError.managedObjectContextNotAvailable)
        }
        
        let entity = NSEntityDescription.entity(forEntityName: entityName, in: context!)!
        let fetchRequest = NSFetchRequest<ResultType>(entityName: entityName)
        fetchRequest.predicate = NSPredicate(format: "%K == %@", entity.identifierName!, identifier as CVarArg)
        
        do {
            let object = try context!.fetch(fetchRequest).first
            return Result.success(object)
        } catch {
            return Result.failure(error)
        }
    }
    
    
    public static func fetchObjects<ResultType: NSManagedObject>(ofType entityName: String, withIds identifiers: [AnyHashable], in context: NSManagedObjectContext? = mainContext) -> Result<[ResultType]> {
        
        guard context != nil else {
            return Result.failure(BootstrapError.managedObjectContextNotAvailable)
        }
        
        let entity = NSEntityDescription.entity(forEntityName: entityName, in: context!)!
        let fetchRequest = NSFetchRequest<ResultType>(entityName: entityName)
        fetchRequest.predicate = NSPredicate(format: "%K IN %@", entity.identifierName!, identifiers)
        
        do {
            let objects = try context!.fetch(fetchRequest)
            return Result.success(objects)
        } catch {
            return Result.failure(error)
        }
    }
    
    
    // MARK: - Private implementation details
    
    private static var stagedDictionariesByEntityName = [String: [[String: Any]]]()
    private static var dictionariesByEntityAndId = [AnyHashable: [String: Any]]()
    private static var objectsByEntityAndId = [AnyHashable: NSManagedObject]()
    
    
    private init() {  }
}
