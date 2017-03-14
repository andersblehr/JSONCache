//
//  DataCache.swift
//  DataCache
//
//  Created by Anders Blehr on 07/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import CoreData
import Foundation


internal struct DataCache {
    
    internal static var modelName: String! = nil
    internal static var context: NSManagedObjectContext! = {
        
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
    
    internal static func stageChanges(withDictionary dictionary: [String: Any], forEntityWithName entityName: String) {
        
        stageChanges(withDictionaries: [dictionary], forEntityWithName: entityName)
    }
    
    
    internal static func stageChanges(withDictionaries dictionaries: [[String: Any]], forEntityWithName entityName: String) {
        
        var stagedDictionaries = [[String: Any]]()
        for dictionary in dictionaries {
            stagedDictionaries.append(JSONConverter.convert(.fromJSON, dictionary: dictionary, qualifier: entityName))
        }
        
        stagedDictionariesByEntityName[entityName] = stagedDictionaries
    }
    
    
    internal static func applyChanges() throws {
        
        for (entityName, dictionaries) in stagedDictionariesByEntityName {
            for dictionary in dictionaries {
                let identifierName = NSEntityDescription.entity(forEntityName: entityName, in: context)!.identifierName!
                let objectId = dictionary[identifierName] as! AnyHashable
                
                var object = try fetchObject(ofType: entityName, withId: objectId)
                if object == nil {
                    object = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
                    objectsByEntityAndId["\(entityName).\(objectId)"] = object
                    dictionariesByEntityAndId["\(entityName).\(objectId)"] = dictionary
                }
                
                object!.setAttributes(fromDictionary: dictionary)
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
                        if let destinationObject = try fetchObject(ofType: destinationEntityName, withId: destinationId) {
                            object.setValue(destinationObject, forKey: relationshipName)
                        }
                    }
                }
            }
        }
        
        try save()
        
        stagedDictionariesByEntityName.removeAll()
        dictionariesByEntityAndId.removeAll()
        objectsByEntityAndId.removeAll()
    }
    
    
    // MARK: - General Core Data interaction
    
    internal static func save() throws {
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                context.rollback()
                
                throw error
            }
        }
    }
    
    
    internal static func fetchObject<ResultType: NSManagedObject>(ofType entityName: String, withId identifier: AnyHashable) throws -> ResultType? {
        
        let entity = NSEntityDescription.entity(forEntityName: entityName, in: context)!
        let fetchRequest = NSFetchRequest<ResultType>(entityName: entityName)
        fetchRequest.predicate = NSPredicate(format: "%K == %@", entity.identifierName!, identifier as CVarArg)
        
        return try context.fetch(fetchRequest).first
    }
    
    
    internal static func fetchObjects<ResultType: NSManagedObject>(ofType entityName: String, withIds identifiers: [AnyHashable]) throws -> [ResultType] {
        
        let entity = NSEntityDescription.entity(forEntityName: entityName, in: context)!
        let fetchRequest = NSFetchRequest<ResultType>(entityName: entityName)
        fetchRequest.predicate = NSPredicate(format: "%K IN %@", entity.identifierName!, identifiers)
        
        return try context.fetch(fetchRequest)
    }
    
    
    // MARK: - Private implementation details
    
    private static var stagedDictionariesByEntityName = [String: [[String: Any]]]()
    private static var dictionariesByEntityAndId = [AnyHashable: [String: Any]]()
    private static var objectsByEntityAndId = [AnyHashable: NSManagedObject]()
    
    
    private init() {  }
}
