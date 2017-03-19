# DataCache

DataCache is a thin layer on top of Core Data that seamlessly
consumes, caches and produces JSON data.

- Automatic mapping between `camelCase` and `snake_case`.
- Automatic relationship mapping, based on inferred knowledge of your
  Core Data model.
- Automatic merging of JSON data into existing objects.
- On-demand JSON generation, both from `NSManageObject` instances, and
  from any `struct` that adopts the `JSONifiable` protocol.
- All JSON parsing and Core Data operations are done in the
  background, so doesn't interfere with your app's responsiveness.

## Show, don't tell

Say your backend produces JSON like this:

```json
{
  "bands": [
    {
      "name": "Japan",
      "formed": 1974,
      "disbanded": 1991,
      "hiatus": "1982-1989",
      "description": "Initially a glam-inspired group [...]"
    },
    ...
  ],
  "band_members": [
    {
      "id": "David Sylvian in Japan",
      "musician": "David Sylvian",
      "band": "Japan",
      "instruments": "Lead vocals, keyboards, guitar",
      "joined": 1974,
      "left": 1991
    },
    ...
  ],
  "musicians": [
    {
      "name": "David Sylvian",
      "born": 1958,
      "instruments": "Vocals, guitar, keyboards"
    },
    ...
  ],
  "albums": [
    {
      "name": "Gentlemen Take Polaroids",
      "band": "Japan",
      "released": "1980-10-24T00:00:00Z",
      "label": "Virgin"
    },
    ...
  ]
}
```

To cache this data in your app, you create a suitable Core Data model:

![](images/model.png)

And with only a few lines of code, the JSON data is safely persisted
in Core Data on your device, relationships and all:

```swift
import DataCache

...

let jsonObject = try! JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
let bands = jsonObject["bands"] as! [[String: Any]]
let bandMembers = jsonObject["band_members"] as! [[String: Any]]
let musicians = jsonObject["musicians"] as! [[String: Any]]
let albums = jsonObject["albums"] as! [[String: Any]]
        
JSONConverter.casing = .snake_case
JSONConverter.dateFormat = .iso8601WithSeparators
        
DataCache.bootstrap(withModelName: "Bands") { result in
  switch result {
  case .success:
    DataCache.stageChanges(withDictionaries: bands, forEntityWithName: "Band")
    DataCache.stageChanges(withDictionaries: bandMembers, forEntityWithName: "BandMember")
    DataCache.stageChanges(withDictionaries: musicians, forEntityWithName: "Musician")
    DataCache.stageChanges(withDictionaries: albums, forEntityWithName: "Album")
    DataCache.applyChanges { result in
      switch result {
      case .success:
        print("Data all nicely tucked in")
      case .failure(let error):
        print("An error occurred: \(error)")
      }
    }
  case .failure(let error):
    print("An error occurred: \(error)")
  }
}
```

If you receive additional data at a later stage it's even simpler:

```swift
let albums = jsonObject["albums"] as! [[String: Any]]

DataCache.stageChanges(withDictionaries: albums, forEntityWithName: "Album")
DataCache.applyChanges { result in
  switch result {
  case .success:
    print("Data all nicely tucked in")
  case .failure(let error):
    print("An error occurred: \(error)")
  }
}
```

And if your app allows producing as well as consuming data, you can
generate JSON directly from `NSManagedObject` instances:

```swift
switch DataCache.fetchObject(ofType: "Band", withId: "Japan") {
  case .success(let japan):
    var japan = japan as! Band
    japan.otherNames = "Rain Tree Crow"
    
    ServerProxy.update(band: japan.toJSONDictionary()) { result in
      switch result {
      case .success:
        switch DataCache.save() {
          case .success:
            print("Japan as Rain Tree Crow all nicely tucked in")
          case .failure(let error):
            print("An error occurred: \(error)")
        }
      case .failure(let error):
        print("An error occurred: \(error)")
      }
    }
  case .failure(let error):
    print("An error occurred: \(error)")
}
```

To create and persist new objects to the backend, you can either
create the `NSManagedObject` instance first and then use it to
generate JSON for the backend, or if you prefer to wait until the
record is safely persisted on the backend, you can generate JSON from
any `struct` that adopts the `JSONifiable` protocol:

```swift
struct BandInfo: JSONifiable {
  var name: String
  var bandDescription: String
  var formed: Int
  var disbanded: Int?
  var hiatus: Int?
  var otherNames: String?
}

let u2Info = BandInfo(name: "U2", bandDescription: "Dublin boys", formed: 1976, disbanded: nil, hiatus: nil, otherNames: "Passengers")

ServerProxy.save(band: u2Info.toJSONDictionary()) { result in
  switch result {
  case .success:
    u2 = NSEntityDescription.insertNewObject(forEntityName: "Band" into: DataCache.mainContext)!
    u2.setAttributes(fromDictionary: u2Info)
    
    switch DataCache.save() {
    case .success:
      print("U2 all nicely tucked in")
    case .failure(let error)
      print("An error occurred: \(error)")
    }
  case .failure(let error):
    print("An error occurred: \(error)")
}
```
