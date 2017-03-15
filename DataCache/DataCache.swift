//
//  DataCache.swift
//  DataCache
//
//  Created by Anders Blehr on 07/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import CoreData
import Foundation


public struct DataCache {
    
    public static var modelName: String! = nil
    public static var mainContext: NSManagedObjectContext! = {
        
        if #available(iOS 10.0, *) {
            let persistentContainer = NSPersistentContainer(name: modelName)
            persistentContainer.loadPersistentStores { (_, error) in
                
                guard error == nil else {
                    return
                }
            }
            
            return persistentContainer.viewContext
        } else {
            let modelURL = Bundle.main.url(forResource: modelName, withExtension: "momd")!
            let model = NSManagedObjectModel(contentsOf: modelURL)!
            let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
            let documentDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
            let persistentStoreURL = documentDirectoryURL.appendingPathComponent("\(modelName).sqlite")
            
            do {
                try persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: persistentStoreURL, options: [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true])
                
                let managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
                managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
                
                return managedObjectContext
            } catch {
                return nil
            }
        }
    }()
    
    
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
        
        let backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundContext.parent = mainContext
        backgroundContext.perform {
            
            for (entityName, dictionaries) in stagedDictionariesByEntityName {
                for dictionary in dictionaries {
                    let identifierName = NSEntityDescription.entity(forEntityName: entityName, in: backgroundContext)!.identifierName!
                    let objectId = dictionary[identifierName] as! AnyHashable
                    
                    switch fetchObject(ofType: entityName, withId: objectId) {
                    case .success(var object):
                        if object == nil {
                            object = NSEntityDescription.insertNewObject(forEntityName: entityName, into: backgroundContext)
                            objectsByEntityAndId["\(entityName).\(objectId)"] = object
                            dictionariesByEntityAndId["\(entityName).\(objectId)"] = dictionary
                        }
                        
                        object!.setAttributes(fromDictionary: dictionary)
                    case .failure(let error):
                        completion(Result.failure(error))
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
                            switch fetchObject(ofType: destinationEntityName, withId: destinationId) {
                            case .success(let destinationObject):
                                if let destinationObject = destinationObject {
                                    object.setValue(destinationObject, forKey: relationshipName)
                                }
                            case .failure(let error):
                                completion(Result.failure(error))
                            }
                        }
                    }
                }
            }
            
            switch save(context: backgroundContext) {
            case .success():
                mainContext.performAndWait {
                    switch save() {
                    case .success():
                        completion(Result.success())
                    case .failure(let error):
                        completion(Result.failure(error))
                    }
                    
                    stagedDictionariesByEntityName.removeAll()
                    dictionariesByEntityAndId.removeAll()
                    objectsByEntityAndId.removeAll()
                }
            case .failure(let error):
                completion(Result.failure(error))
            }
        }
    }
    
    
    // MARK: - General Core Data interaction
    
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
    
    
    public static func fetchObject<ResultType: NSManagedObject>(ofType entityName: String, withId identifier: AnyHashable) -> Result<ResultType?> {
        
        let entity = NSEntityDescription.entity(forEntityName: entityName, in: mainContext)!
        let fetchRequest = NSFetchRequest<ResultType>(entityName: entityName)
        fetchRequest.predicate = NSPredicate(format: "%K == %@", entity.identifierName!, identifier as CVarArg)
        
        do {
            let object = try mainContext.fetch(fetchRequest).first
            return Result.success(object)
        } catch {
            return Result.failure(error)
        }
    }
    
    
    public static func fetchObjects<ResultType: NSManagedObject>(ofType entityName: String, withIds identifiers: [AnyHashable]) -> Result<[ResultType]> {
        
        let entity = NSEntityDescription.entity(forEntityName: entityName, in: mainContext)!
        let fetchRequest = NSFetchRequest<ResultType>(entityName: entityName)
        fetchRequest.predicate = NSPredicate(format: "%K IN %@", entity.identifierName!, identifiers)
        
        do {
            let objects = try mainContext.fetch(fetchRequest).first
            return Result.success(objects as! [ResultType])
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
