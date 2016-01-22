# iModel

[![build](https://travis-ci.org/theddnc/iModel.svg?branch=master)](https://travis-ci.org/theddnc/iModel)
[![CocoaPods](https://img.shields.io/cocoapods/v/iModel.svg)](https://cocoapods.org/pods/iModel)
[![CocoaPods](https://img.shields.io/cocoapods/l/iModel.svg)](https://cocoapods.org/pods/iModel)
[![CocoaPods](https://img.shields.io/cocoapods/p/iModel.svg)](https://cocoapods.org/pods/iModel)
[![CocoaPods](https://img.shields.io/cocoapods/metrics/doc-percent/iModel.svg)](http://cocoadocs.org/docsets/iModel/0.0.6/)

Validation, JSON parsing and async remote communication in one bundle.

## Installation

Copy this line into your podfile:

```pod 'iModel', '~> 0.0'```

Make sure to also add ```!use_frameworks```

## Description

iModel was created to provide a simple boilerplate for creating data models. It provides
data validation and a CRUD over HTTP interface with seamless JSON parsing.

#### Model

```Model``` provides means for data validation and property observing. 

##### Property observing

All properties that are marked as ```dynamic``` will be observed by obj-c KVO. 
That means you have to declare your property as ```dynamic``` to add KVO to it: 

```swift
class SimpleModel: Model {
    public dynamic var id: Int = 0                  //this will be observed
    public var unobservableProperty: String = ""    //this won't
}
```

Override:

```swift
property<T>(property: String, changedFromValue oldValue: T, toValue newValue: T)
```

For any custom behaviour on property change.

##### Validation

```Model``` has its ```validationState```. When a ```Model``` object is created, its state
is equal to ```Model.ValidationState.Empty```. When properties of a model change, it transitions
to ```.Dirty``` state and ```Model.dirtyProperties``` array is populated with properties that
have changed. Then, after the user calls ```validate()``` object transitions to either ```.Clean```
or ```.Invalid``` state, depending on validation methods' results. ```Model.validationErrors``` is
available when any of the valdiation methods fails and the object is ```.Invalid``` Models's last 
```.Clean``` or ```.Empty``` state can be restored by calling ```undo()```. 

##### Adding validation methods

Validation methods take a fields value as an argument and return a tuple of ```(Bool, String)```.
The boolean flag indicates whether the field's value is valid and the string value contains any
error message. 

Define your validation methods as ```public class func```:

```swift
class SimpleModel: Model {
    public dynamic var id: Int = 0

    public class func validateId(id: Int) -> (Bool, String) {
        if (id <= 0) {
            return (false, "Id should be greater that zero!")
        }
        return (true, "")
    }
}
```

Then, call ```setValidationMethod(:forField)``` from, for example, ```AppDelegate.didFinishLaunchingWithOptions```:

```swift
SimpleModel.setValidationMethod(SimpleModel.validateId, forField: "id")
```

```validateId()``` will be called on each ```validate()``` call.

#### JsonModel

```JsonModel``` extends ```Model``` with JSON files parsing utilities. Basic usage of
this class will be to name all properties using keys from the corresponding json file.

**NOTE**: this class uses NSJSONSerialization. 

##### Simple example

Let's assume that we have a following JSON file in a form of NSData (returned by NSURLRequest)

```json
{
    "id": 10,
    "first_name": "Matthew",
    "last_name": "Johnson",
    "age": 23
}
```

Following snippet will parse it into a ```JsonModel``` object:

```swift
class Person: JsonModel {
    public dynamic var id: Int?
    public dynamic var firstName: String?           //can also be first_name
    public dynamic var lastName: String?            //can also be last_name
    public dynamic var age: Int?
}

// let data = ... - a NSData object
let matthew = Person(data: data)

print(matthew.toJsonDictionary())                   //this will print a [String: AnyObject] dict
```

##### Advanced configuration

Example below shows more advanced configuration:

```swift
class SimpleNestedModel: JsonModel {
    public dynamic var value: String = ""
}

class SimpleJsonModel: JsonModel {
    public dynamic var id: Int = 0
    public dynamic var name: String = ""
    public dynamic var optionalValue: Int?
    public dynamic var nested: SimpleNestedModel?

    override public class func jsonPropertyExclusions() -> [String] {
        // we don't want to waste time parsing these:
        return ["please_parse_me", "important_value"]
    }

    override public class func jsonPropertyNames() -> [String: String] {
        // API returns some weird names, we want our own:
        return [
            "name_of_this_object": "name",
            "id_of_this_object": "id"
        ]
    }

    override public class func jsonPropertyParsingMethods() -> [String: (AnyObject) throws -> AnyObject] {
        // we have a nested JsonModel, lets parse it
        return ["nested": SimpleNestedModel.fromJsonDictionary]
    }

    override public class func jsonBeforeDeserialize(data: [String: AnyObject]) -> [String: AnyObject] {
        // modify the raw json dictionary however you want before parsing it into an object
        return data
    }

    override public class func jsonAfterSerialize(data: [String: AnyObject]) -> [String: AnyObject] {
        // modify the raw json dictionary however you want after serializing (before returning from 
        // toJsonDictionary
        return data
    }
}
```

#### RestfulModel

```RestfulModel```, being a subclass of JsonModel, contains all the validation capabilities and
JSON parsing utilities as its base class, and extends this functionality by adding CRUD 
interface which allows transmitting data to and from a remote server (a RESTful API).

```RestfulModel``` uses [iService](https://github.com/theddnc/iService) and 
[iPromise](https://github.com/theddnc/iPromise) for API communication and asynchrony. Its
CRUD interface mimics the one from iService.

**NOTE**: Following methods should be overridden everytime when subclassing:

1. ```urlOfService``` - provides the service url to use when communicating with an API
2. ```path()``` - provides object identifier for the API

##### Basic use case

```swift
class Post: RestfulModel {
    public dynamic var id: Int?
    public dynamic var body: String?
    public dynamic var title: String?
    public dynamic var userId: Int?
    
    override public class func urlOfService() -> NSURL {
        return NSURL(string: "http://jsonplaceholder.typicode.com/post"
    }

    override public func path() -> String {
        return "\(id)"
    }
}
```

##### Creating an object

```swift
let post = Post()
post.body = "A body"
post.title = "My first post!"
post.userId = 10

Post.create(post).then({ /*...*/ })
```

##### Retrieving single item

```swift
Post.retrieve("1").then({ (result: Post) in
    //we have our post here ...
})
```

##### Retrieving a filtered list

```swift
Post.retrieve("userId": "1").then({ /*...*/ })    //HTTP GET on http://jsonplaceholder.typicode.com/post/?userId=1&
```

##### Updating an object

```swift
// updating an object
let post = Post()
post.body = "new body"
post.id = 10

post.update().then({ /*...*/ })
```

##### Deleting an object

```swift
let post = Post()
post.id = 100

post.destroy().then({ /*...*/ })
```

##### Advanced behaviour

Restful model provides many handles to override its basic functionality. Override any
of the following methods as needed.

0. ```crudConfigureRequestFor...``` - configure request for each of CRUD methods
1. ```crudAugmentCreate``` - provides means to add any additional data before
sending a ```CREATE``` request
2. ```crudAugmentUpdate```- provides means to add any additional data before
sending an ```UPDATE``` request
3. ```crudAugmentRetrieve``` - provides means to add any additional data before parsing
the JSON data into an object

For more information about these methods, visit the documentation. 

## Documentation

Documentation should be available [here](http://cocoadocs.org/docsets/iModel/0.0.6/), although there seems to be an issue 
with the lib that cocoapods use to generate docs from code. For now just read the comments - it will also help you to better
understand the lib and possibly find some issues with it!  

## Licence

See [LICENCE](https://github.com/theddnc/iModel/blob/master/LICENCE)