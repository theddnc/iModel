//
//  RestfulModel.swift
//  iPromise
//
//  Created by jzaczek on 13.11.2015.
//  Copyright © 2015 jzaczek. All rights reserved.
//

import Foundation

/**
**TODO**: think of a way to allow json parsing without providing CRUD - another class?
**TODO**: ```jsonPropertyClasses``` - provides initializers for properties that can be
represented by a class - what interface? a protocol?

Restful model, being a subclass of Model, contains all the validation capabilities and
property observers as its base class, and extends this functionality by adding CRUD 
interface which allows transmitting data to and from a remote server. 

**NOTE**: Following methods should be overridden everytime when subclassing:

1. ```urlOfService``` - provides the service url to use when communicating with an API
2. ```path()``` - provides object identifier for the API

**NOTE**: Override ```nameOfServiceRealm``` to use request configuration common for many
```Serivce```s or ```RestfulModel```s.

Restful model provides many handles to override its basic functionality. Override any
of the following methods as needed.

0. ```requestConfigureFor...``` - configure request for each of CRUD methods
1. ```jsonPropertyExclusions``` - excludes a list of JSON keys from parsing
2. ```jsonPropertyNames``` - provides a map which links JSON key to object's property 
    name
3. ```jsonPropertyParsingMethods``` - provides methods which override default parsing
    logic
4. ```jsonAugmentCreate``` - provides means to add any additional data before
    sending a ```CREATE``` request
5. ```jsonAugmentUpdate```- provides means to add any additional data before
    sending an ```UPDATE``` request
6. ```jsonAugmentRetrieve``` - provides means to add any additional data before parsing
    the JSON data into an object
*/
public class RestfulModel: JsonModel {
    
    /// Service for fetching and saving data
    private static var _restService: Service?
    
    /// Service for fetching and saving data
    private static var RestService: Service {
        get {
            if _restService == nil {
                _restService = Service(serviceUrl: self.urlOfService())
                
                // register in service realm
                if let name = self.nameOfServiceRealm() {
                    ServiceRealm.get(name).register(_restService!)
                }
            }
            return _restService!
        }
    }
    
    public override init() {
        super.init()
    }
    
    public required init(jsonDict: [String : AnyObject]) throws {
        try super.init(jsonDict: jsonDict)
    }
    
    /**
    Returns a NSURL of a service that should manage persitstence of this class.
    
    - returns: A NSURL of REST service.
    */
    public class func urlOfService() -> NSURL {
        fatalError("This method should be overriden in order to use RESTful functionalities")
    }
    
    /**
    Override to specify an identifier for this model's service's realm.
    
     - returns: ```ServiceRealm```'s name if specified, ```nil``` otherwise
    */
    public class func nameOfServiceRealm() -> String? {
        return nil
    }
    
    /**
    Called as an ```override()``` for this model's service's service realm before 
    firing a ```CREATE``` request.
    */
    public class func requestConfigureForCreate(realm: ServiceRealm) {
        
    }
    
    /**
    Called as an ```override()``` for this model's service's service realm before
    firing a ```RETRIEVE``` request.
    */
    public class func requestConfigureForRetrieve(realm: ServiceRealm) {
        
    }
    
    /**
    Called as an ```override()``` for this model's service's service realm before
    firing an ```UPDATE``` request.
    */
    public class func requestConfigureForUpdate(realm: ServiceRealm) {
        
    }
    
    /**
    Called as an ```override()``` for this model's service's service realm before
    firing a ```DELETE``` request.
    */
    public class func requestConfigureForDestroy(realm: ServiceRealm) {
        
    }
    
    /**
    Returns a full path to the object, relative to the service base url. Used for identifying
    objects in the REST api when updating and deleting objects. 
    
     - returns: A String URI path which identifies the object.
    */
    public func path() -> String {
        fatalError("This method needs to be overriden to provide identifiers for REST interface")
    }
    
    
    /**
    Called just after the object is parsed into a dictionary of its properties. Provides
    means for adding any additional information before sending a CREATE request.
    */
    public class func jsonAugmentCreate(data: [String: AnyObject]) -> [String: AnyObject] {
        return data
    }
    
    /**
    Called just after the object is parsed into a dictionary of its properties. Provides
    means for adding any additional information before sending a UPDATE request.
    */
    public class func jsonAugmentUpdate(data: [String: AnyObject]) -> [String: AnyObject] {
        return data
    }
    
    /**
    Called just after the received data is parsed into a dictionary of json key-values. Provides
    means for adding any additional information before parsing the object.
    */
    public class func jsonAugmentRetrieve(data: [String: AnyObject]) -> [String: AnyObject] {
        return data
    }
    
    
    // MARK: - CRUD interface
    
    
    /**
    Fires a create request.
    
    - parameter model: Model to be creted in the persistend store of the backend.
    - returns: A promise of the backend's response
    */
    public class func create(model: RestfulModel) -> Promise {
        return Promise {
            (fulfill, reject) in
            let data = try model.createNSDataFor(.CREATE)
            let promise = self.RestService
                .override(requestConfigureForCreate)
                .create(data)
                .success(retrieveSuccess)
            
            
            fulfill(promise)
        }
    }
    
    /**
    Retrieve an object idetified by ```path```.
    
    - parameter path: An uri path to retrieve from.
    - returns: A promise of the retrieved ```RestfulModel```
    */
    public class func retrieve(path: String) -> Promise {
        return self.RestService
            .override(requestConfigureForRetrieve)
            .retrieve(path)
            .success(retrieveSuccess)
    }
    
    /**
    Retrieve all objects from the server. 
    */
    public class func retrieve() -> Promise {
        return self.RestService
            .override(requestConfigureForRetrieve)
            .retrieve()
            .success(retrieveManySuccess)
    }
    
    /**
    Retrieve a filtered list of objects from the server.
    */
    public class func retrieve(filter: [String: String]) -> Promise {
        return self.RestService
            .override(requestConfigureForRetrieve)
            .retrieve(filter)
            .success(retrieveManySuccess)
    }
    
    /**
    Update this object's copy on the server. Calls ```path()``` to
    identify object to be destroyed.
    
     - returns: Promise of the updated object.
    */
    public func update() -> Promise {
        return Promise {
            (fulfill, reject) in
            let data = try self.createNSDataFor(.UPDATE)
            let path = self.path()
            
            fulfill(RestfulModel.RestService
                .override(self.dynamicType.requestConfigureForUpdate)
                .update(path, data: data)
                .success(self.dynamicType.retrieveSuccess))
        }
    }
    
    /**
    Destroy this object's copy on the server. Calls ```path()``` to 
    identify object to be destroyed.
    
     - returns: Promise of the result.
    */
    public func destroy() -> Promise {
        return RestfulModel.RestService
            .override(self.dynamicType.requestConfigureForDestroy)
            .destroy(self.path())
    }
    
    
    // MARK: - private
    
    
    /**
    Tries to parse data returned from API into an instance of this class. Called as a
    handler for retrieve promise.
    */
    private class func retrieveSuccess(result: Any) throws -> Any {
        guard let (data, _) = result as? (NSData, NSURLResponse) else {
            throw ModelError.ServiceError(result)   //this should never happen when using services correctly
        }
        
        var jsonDict = try Utils.dictionaryFromData(data)
        jsonDict = jsonAugmentRetrieve(jsonDict)
        
        return try self.init(jsonDict: jsonDict)
    }
    
    /**
    Tries to parse data returned from API into an array of instances of this class. Called
    as a handler for retrieve promise.
    */
    private class func retrieveManySuccess(result: Any) throws -> Any {
        guard let (data, _) = result as? (NSData, NSURLResponse) else {
            throw ModelError.ServiceError(result)   //this should never happen when using services correctly
        }
        
        let array = try Utils.arrayFromData(data)
        
        return try array
            .map({$0 as! [String:AnyObject]})
            .map(self.jsonAugmentRetrieve)
            .map(self.init)
    }
    
    /**
    For a given json key, property map and class property names, get a correct
    property name. 
    
     - parameter key: JSON dictionary key, that will be mapped to a property name
     - parameter propertyNames: a dictionary that maps json property names to class property names
     - parameter classProperties: an array of class properties (provided by reflection)
    
     - returns: Correctly mapped property name, or nil, if a property couldn't be found on object
    */
    private class func getPropertyNameFromKey(key: String, propertyNames: [String: String], classProperties: [String]) -> String? {
        if propertyNames.keys.contains(key) && classProperties.contains(propertyNames[key]!){
            return propertyNames[key]!
        }
        
        if key.containsString("_") && classProperties.contains(Utils.toCamelCase(key)) {
            return Utils.toCamelCase(propertyNames[key]!)
        }
        
        if classProperties.contains(key) {
            return key
        }
        
        return nil
    }
    
    /**
    Encodes this object into a NSData object. Uses provided overriden 
    ```jsonPropertyNames()``` dictionary. 
    
    - returns: encoded NSData
    */
    private func createNSDataFor(method: Service.CRUDMethod) throws -> NSData {
        var dict: [String: AnyObject] = self.createJsonDictionary()
        
        switch method {
        case .CREATE:
            dict = self.dynamicType.jsonAugmentCreate(dict)
        case .UPDATE:
            dict = self.dynamicType.jsonAugmentUpdate(dict)
        default:
            break
        }
        
        return NSKeyedArchiver.archivedDataWithRootObject(dict)
    }
}