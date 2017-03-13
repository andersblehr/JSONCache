//
//  DataCache.swift
//
//  Created by Anders Blehr on 07/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import CoreData
import Foundation


internal struct DataCache {
    
    internal static var cache = DataCache()
    internal var modelName: String! = nil
    internal lazy var context: NSManagedObjectContext! = {
        
        if #available(iOS 10.0, *) {
            let persistentContainer = NSPersistentContainer(name: self.modelName)
            persistentContainer.loadPersistentStores { (_, error) in
                
                guard error == nil else {
                    return
                }
            }
            
            return persistentContainer.viewContext
        } else {
            let modelURL = Bundle.main.url(forResource: self.modelName, withExtension: "momd")!
            let model = NSManagedObjectModel(contentsOf: modelURL)!
            let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
            let documentDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
            let persistentStoreURL = documentDirectoryURL.appendingPathComponent("\(self.modelName).sqlite")
            
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
    
    internal mutating func stageChanges(withDictionary dictionary: [String: Any], forEntityWithName entityName: String, casing: CamelSnake.Casing = .snake_case) {
        
        stageChanges(withDictionaries: [dictionary], forEntityWithName: entityName, casing: casing)
    }
    
    
    internal mutating func stageChanges(withDictionaries dictionaries: [[String: Any]], forEntityWithName entityName: String, casing: CamelSnake.Casing = .snake_case) {
        
        var stagedDictionaries = [[String: Any]]()
        
        for dictionary in dictionaries {
            let camelCaseDictionary = casing == .camelCase ? dictionary : CamelSnake.convert(dictionary: dictionary, toCase: .camelCase, qualifier: entityName)
            
            stagedDictionaries.append(camelCaseDictionary)
        }
        
        stagedDictionariesByEntityName[entityName] = stagedDictionaries
    }
    
    
    internal mutating func applyChanges() throws {
        
        for (entityName, dictionaries) in stagedDictionariesByEntityName {
            for dictionary in dictionaries {
                let identifierName = NSEntityDescription.entity(forEntityName: entityName, in: context)!.identifierName!
                let objectId = dictionary[identifierName] as! String
                
                var object = try fetchObject(ofType: entityName, withId: objectId)
                if object == nil {
                    object = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
                    objectsById[objectId] = object
                    dictionariesById[objectId] = dictionary
                }
                
                object!.setAttributes(fromDictionary: dictionary)
            }
        }
        
        for (objectId, object) in objectsById {
            for (relationshipName, relationship) in object.entity.relationshipsByName {
                if !relationship.isToMany {
                    let dictionary = dictionariesById[objectId]!
                    let destinationId = dictionary[relationshipName] as! AnyHashable
                    
                    if let destinationObject = objectsById[destinationId] {
                        object.setValue(destinationObject, forKey: relationshipName)
                    } else {
                        let destinationEntityName = relationship.destinationEntity!.name!
                        if let destinationObject = try DataCache.cache.fetchObject(ofType: destinationEntityName, withId: destinationId) {
                            object.setValue(destinationObject, forKey: relationshipName)
                        }
                    }
                }
            }
        }
        
        try save()
        
        stagedDictionariesByEntityName.removeAll()
        dictionariesById.removeAll()
        objectsById.removeAll()
    }
    
    
    // MARK: - General Core Data interaction
    
    internal mutating func save() throws {
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                context.rollback()
                
                throw error
            }
        }
    }
    
    
    internal mutating func fetchObject<ResultType: NSManagedObject>(ofType entityName: String, withId identifier: AnyHashable) throws -> ResultType? {
        
        let entity = NSEntityDescription.entity(forEntityName: entityName, in: context)!
        let fetchRequest = NSFetchRequest<ResultType>(entityName: entityName)
        fetchRequest.predicate = NSPredicate(format: "%K == %@", entity.identifierName!, identifier as CVarArg)
        
        return try context.fetch(fetchRequest).first
    }
    
    
    internal mutating func fetchObjects<ResultType: NSManagedObject>(ofType entityName: String, withIds identifiers: [AnyHashable]) throws -> [ResultType] {
        
        let entity = NSEntityDescription.entity(forEntityName: entityName, in: context)!
        let fetchRequest = NSFetchRequest<ResultType>(entityName: entityName)
        fetchRequest.predicate = NSPredicate(format: "%K IN %@", entity.identifierName!, identifiers)
        
        return try context.fetch(fetchRequest)
    }
    
    
    // MARK: - Private implementation details
    
    private var stagedDictionariesByEntityName = [String: [[String: Any]]]()
    private var dictionariesById = [AnyHashable: [String: Any]]()
    private var objectsById = [AnyHashable: NSManagedObject]()
    
    
    private init() {  }
}
