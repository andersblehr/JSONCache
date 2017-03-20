# JSONCache

JSONCache is a thin layer on top of Core Data that seamlessly
consumes, caches and produces JSON data.

- Automatic mapping between `camelCase` and `snake_case`.
- Automatic relationship mapping, based on inferred knowledge of your
  Core Data model.
- Automatic merging of JSON data into existing objects.
- On-demand JSON generation, both from `NSManageObject` instances, and
  from any `struct` that adopts the `JSONifiable` protocol.
- All JSON parsing and Core Data operations are done in the
  background, so it doesn't interfere with your app's responsiveness.

## Content

- [Show, don't tell](#show-dont-tell)
  - [Consuming JSON](#consuming-json)
  - [Producing JSON](#producing-json)
- [But do tell](#but-do-tell)
  - [Case conversion](#case-conversion)
  - [Date conversion](#date-conversion)
  - [Relationship mapping](#relationship-mapping)
    - [Entity primary key](#entity-primary-key)
    - [JSON foreign key](#json-foreign-key)
- [Installation](#installation)
  - [CocoaPods](#cocoapods)
  - [Carthage](#carthage)
  - [Compatibility](#compatibility)
- [License](#license)

## Show, don't tell

### Consuming JSON

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
import JSONCache

...

let jsonObject = try! JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
let bands = jsonObject["bands"] as! [[String: Any]]
let bandMembers = jsonObject["band_members"] as! [[String: Any]]
let musicians = jsonObject["musicians"] as! [[String: Any]]
let albums = jsonObject["albums"] as! [[String: Any]]
        
JSONCache.casing = .snake_case
JSONCache.dateFormat = .iso8601WithSeparators
        
JSONCache.bootstrap(withModelName: "Bands") { result in
  switch result {
  case .success:
    JSONCache.stageChanges(withDictionaries: bands, forEntityWithName: "Band")
    JSONCache.stageChanges(withDictionaries: bandMembers, forEntityWithName: "BandMember")
    JSONCache.stageChanges(withDictionaries: musicians, forEntityWithName: "Musician")
    JSONCache.stageChanges(withDictionaries: albums, forEntityWithName: "Album")
    JSONCache.applyChanges { result in
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

JSONCache.stageChanges(withDictionaries: albums, forEntityWithName: "Album")
JSONCache.applyChanges { result in
  switch result {
  case .success:
    print("Data all nicely tucked in")
  case .failure(let error):
    print("An error occurred: \(error)")
  }
}
```

### Producing JSON

If your app allows producing as well as consuming data, you can
generate JSON directly from `NSManagedObject` instances:

```swift
switch JSONCache.fetchObject(ofType: "Band", withId: "Japan") {
  case .success(let japan):
    var japan = japan as! Band
    japan.otherNames = "Rain Tree Crow"
    
    ServerProxy.update(band: japan.toJSONDictionary()) { result in
      switch result {
      case .success:
        switch JSONCache.save() {
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
    u2 = NSEntityDescription.insertNewObject(forEntityName: "Band" into: JSONCache.mainContext)!
    u2.setAttributes(fromDictionary: u2Info)
    
    switch JSONCache.save() {
    case .success:
      print("U2 all nicely tucked in")
    case .failure(let error)
      print("An error occurred: \(error)")
    }
  case .failure(let error):
    print("An error occurred: \(error)")
}
```

## But do tell

### Case conversion

Before JSON data is loaded into Core Data, any necessary case
conversion is performed on the attribute names. The
`JSONCache.casing` configuration parameter tells JSONCache whether
to expect `.snake_case` or `.camelCase` in the JSON data. Case
conversion is only done if the JSON casing is `.snake_case`:

- `attribute_name` becomes `attributeName`.
- `description`, being a reserved attribute name, becomes
  `entityNameDescription`.
  
Similarly, when producing JSON:

- `attributeName` becomes `attribute_name`.
- `entityNameDescription` becomes `description`.

### Date conversion

JSONCache supports the following JSON date formats:

- ISO 8601 with separators: `2000-08-22T13:28:00Z`
- ISO 8601 without separators: `20000822T132800Z`
- Seconds since 00:00 on 1 Jan 1970 as a double precision value:
  `966950880.0`

Use the `JSONCache.dateFormat` configuration parameter to tell
JSONCache which format to expect and/or produce.

### Relationship mapping

For JSONCache to automatically map relationships, two things must be
in place:

1. A primary key for each entity that takes part in a relationship.
2. The foreign key of the target entity in the JSON relationship
   attribute on the 'one end' of one-to-one and one-to-many
   relationships.

Many-to-many relationships are currently not supported, except through
relationship entities (such as the `BandMember` entity in the JSON
example above).

#### Entity primary key

For JSONCache to automatically map relationships, you must mark the
primary key of each entity in your Core Data model. You do this in
either of two ways:

1. Use the name `id` for the primary key. (See Figure 1.)
2. Create a User Info key named `DC.isIdentifier` for the primary key
   attribute  and assign it the value `true` or `YES` (both case
   insensitive). (See Figure 2.)
   
The primary key must be unique within an entity, but not across
entities.

![](images/identifier-1.png)

_Figure 1: Marking an entity's primary key by naming it `id`._

![](images/identifier-2.png)

_Figure 2: Marking an entity's primary key by creating a User Info key
named `DC.isIdentifier` and setting it to `true`._

#### JSON foreign key

Consider the following JSON records:

**Musician**
```json
{
  "name": "Mick Karn",  <- Primary key
  "born": 1958,
  "dead": 2011,
  "instruments": "Bass, sax, clarinet, oboe, keyboards, vocals"
}
```

**BandMember**
```json
{
  "id": "Mick Karn in Japan",  <- Primary key
  "musician": "Mick Karn",     <- Foreign key
  "band": "Japan",             <- Foreign key
  "joined": 1974,
  "left": 1991,
  "instruments": "Bass, sax, vocals"
}
```

**Band**
```json
{
  "name": "Japan",  <- Primary key
  "formed": 1974,
  "disbanded": 1991,
  "hiatus": "1982-1989",
  "description": "Initially a glam-inspired group [...]",
  "other_names": "Rain Tree Crow"
}
```

**Album**
```json
{
  "name": "Tin Drum",
  "band": "Japan",  <- Foreign key
  "released": "1981-11-13T00:00:00Z",
  "label": "Virgin"
}
```

The foreign keys in the JSON data correspond to `toOne` relationships
in Core Data. JSONCache retrieves the `NSRelationshipDescription` for
each relationship, uses this to obtain the class of the target object,
looks it up using the foreign key from the JSON dictionary, and
establishes the relationship.

## Installation

You can install JSONCache using either
[CocoaPods](http://cocoapods.org/) or
[Carthage](https://github.com/Carthage/Carthage).

### CocoaPods

```
pod 'JSONCache'
```

### Carthage

```
github "andersblehr/JSONCache" ~> 1.0
```

### Compatibility

- iOS 9.3 or later
- Swift 3.x

Support for other Apple platforms is in the works.

## License

JSONCache is released under the MIT license. See the
[LICENSE](LICENSE) file for details.
