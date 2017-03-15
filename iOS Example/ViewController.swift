//
//  ViewController.swift
//  DataCache
//
//  Created by Anders Blehr on 13/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import CoreData
import UIKit


class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var bandTableView: SelfSizingTableView!
    @IBOutlet weak var memberTableView: SelfSizingTableView!
    @IBOutlet weak var albumTableView: SelfSizingTableView!
    
    
    // MARK: - View lifecycle
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        do {
            bandTableView.dataSource = self
            bandTableView.delegate = self
            memberTableView.dataSource = self
            albumTableView.dataSource = self
            
            let filePath = Bundle.main.path(forResource: "bands", ofType: "json")
            let fileData = try Data(contentsOf: URL(fileURLWithPath: filePath!))
            let jsonObject = try JSONSerialization.jsonObject(with: fileData) as! [String: Any]
            
            let albums = jsonObject["albums"] as! [[String: Any]]
            let bands = jsonObject["bands"] as! [[String: Any]]
            let bandMembers = jsonObject["band_members"] as! [[String: Any]]
            let musicians = jsonObject["musicians"] as! [[String: Any]]
            
            JSONConverter.casing = .snake_case
            JSONConverter.dateFormat = .iso8601WithSeparators
            
            DataCache.modelName = "DataCache"
            DataCache.stageChanges(withDictionaries: albums, forEntityWithName: "Album")
            DataCache.stageChanges(withDictionaries: bands, forEntityWithName: "Band")
            DataCache.stageChanges(withDictionaries: bandMembers, forEntityWithName: "BandMember")
            DataCache.stageChanges(withDictionaries: musicians, forEntityWithName: "Musician")
            DataCache.applyChanges { (result) in

                switch result {
                case .success():
                    do {
                        try self.bandResultsController.performFetch()
                        self.bandTableView.reloadData()
                    } catch {
                        print("An error occurred: \(error)")
                    }
                case .failure(let error):
                    print("An error occurred: \(error)")
                }
            }
        } catch  {
            print("An error occurred: \(error)")
        }
    }
    
    
    // MARK: - UITableViewDataSource conformance
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        if (tableView == bandTableView && bandResultsController.sections != nil) || selectedBand != nil {
            return 1
        }
        
        return 0
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if tableView == bandTableView {
            return bandResultsController.sections![section].numberOfObjects
        } else if tableView == memberTableView {
            return memberResultsController.sections![section].numberOfObjects
        } else {
            return albumResultsController.sections![section].numberOfObjects
        }
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: UITableViewCell! = nil
        
        if tableView == bandTableView {
            let band = bandResultsController.object(at: indexPath)
            
            cell = tableView.dequeueReusableCell(withIdentifier: "band")!
            cell.textLabel!.text = band.name!
            cell.detailTextLabel!.text = "Active \(band.formed)-\(band.disbanded) \(band.hiatus != nil ? "(hiatus \(band.hiatus!)" : ""))"
        } else if tableView == memberTableView {
            let member = memberResultsController.object(at: indexPath)
            let musician = member.musician!
            
            cell = tableView.dequeueReusableCell(withIdentifier: "member")
            cell.textLabel!.text = "\(musician.name!): \(member.instruments!)"
            cell.detailTextLabel!.text = "\(member.joined)-\(member.left) \(musician.dead != 0 ? "(died \(musician.dead))" : "")"
            cell.isUserInteractionEnabled = false
        } else {
            let album = albumResultsController.object(at: indexPath)
            let dateFormatter = DateFormatter()
            dateFormatter.calendar = Calendar(identifier: Calendar.Identifier.iso8601)
            dateFormatter.dateFormat = "MMMM yyyy"
            
            cell = tableView.dequeueReusableCell(withIdentifier: "album")
            cell.textLabel!.text = album.name!
            cell.detailTextLabel!.text = "\(dateFormatter.string(from: album.released as! Date)) (\(album.label!))\(album.releasedAs != nil ? ". Released as \(album.releasedAs!)" : "")"
            cell.isUserInteractionEnabled = false
        }
        
        return cell
    }
    
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        if tableView == bandTableView {
            return "Bands"
        } else if tableView == memberTableView {
            return "Members"
        } else {
            return "Albums"
        }
    }
    
    
    // MARK: - UITableViewDelegate conformance
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        selectedBand = bandResultsController.object(at: indexPath)
        
        do {
            memberResultsController.fetchRequest.predicate = NSPredicate(format: "%K == %@", "band", selectedBand!)
            try memberResultsController.performFetch()
            memberTableView.reloadData()

            albumResultsController.fetchRequest.predicate = NSPredicate(format: "%K == %@", "band", selectedBand!)
            try albumResultsController.performFetch()
            albumTableView.reloadData()
        } catch {
            print("An error occurred: \(error)")
        }
    }
    
    
    // MARK: - Private implementation details
    
    private var selectedBand: Band! = nil
    
    private lazy var bandResultsController: NSFetchedResultsController<Band> = {
        let fetchRequest = NSFetchRequest<Band>(entityName: "Band")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        return NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DataCache.mainContext, sectionNameKeyPath: nil, cacheName: nil)
    }()
    
    private lazy var memberResultsController: NSFetchedResultsController<BandMember> = {
        let fetchRequest = NSFetchRequest<BandMember>(entityName: "BandMember")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "musician.name", ascending: true)]
        
        return NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DataCache.mainContext, sectionNameKeyPath: nil, cacheName: nil)
    }()
    
    private lazy var albumResultsController: NSFetchedResultsController<Album> = {
        let fetchRequest = NSFetchRequest<Album>(entityName: "Album")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "released", ascending: true)]
        
        return NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DataCache.mainContext, sectionNameKeyPath: nil, cacheName: nil)
    }()
}


class SelfSizingTableView: UITableView {
    
    override var contentSize:CGSize { didSet { self.invalidateIntrinsicContentSize() } }
    override var intrinsicContentSize: CGSize {
        get {
            self.layoutIfNeeded()
            
            return CGSize(width: UIViewNoIntrinsicMetric, height: contentSize.height)
        }
    }
}
