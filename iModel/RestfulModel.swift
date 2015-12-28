//
//  RestfulModel.swift
//  iPromise
//
//  Created by jzaczek on 13.11.2015.
//  Copyright © 2015 jzaczek. All rights reserved.
//

import Foundation
import iService
import iPromise

/**
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

0. ```crudConfigureRequestFor...``` - configure request for each of CRUD methods
1. ```crudAugmentCreate``` - provides means to add any additional data before
    sending a ```CREATE``` request
2. ```crudAugmentUpdate```- provides means to add any additional data before
    sending an ```UPDATE``` request
3. ```crudAugmentRetrieve``` - provides means to add any additional data before parsing
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
    public class func crudConfigureRequestForCreate(realm: ServiceRealm) {
        
    }
    
    /**
    Called as an ```override()``` for this model's service's service realm before
    firing a ```RETRIEVE``` request.
    */
    public class func crudConfigureRequestForRetrieve(realm: ServiceRealm) {
        
    }
    
    /**
    Called as an ```override()``` for this model's service's service realm before
    firing an ```UPDATE``` request.
    */
    public class func crudConfigureRequestForUpdate(realm: ServiceRealm) {
        
    }
    
    /**
    Called as an ```override()``` for this model's service's service realm before
    firing a ```DELETE``` request.
    */
    public class func crudConfigureRequestForDestroy(realm: ServiceRealm) {
        
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
    public class func crudAugmentCreate(data: [String: AnyObject]) -> [String: AnyObject] {
        return data
    }
    
    /**
    Called just after the object is parsed into a dictionary of its properties. Provides
    means for adding any additional information before sending a UPDATE request.
    */
    public class func crudAugmentUpdate(data: [String: AnyObject]) -> [String: AnyObject] {
        return data
    }
    
    /**
    Called just after the received data is parsed into a dictionary of json key-values. Provides
    means for adding any additional information before parsing the object.
    */
    public class func crudAugmentRetrieve(data: [String: AnyObject]) -> [String: AnyObject] {
        return data
    }
    
    
    // MARK: - CRUD interface
    
    
    /**
    Fires a create request.
    
    - parameter model: Model to be creted in the persistend store of the backend.
    - returns: A promise of the backend's response
    */
    public class func create(model: RestfulModel) -> Promise<RestfulModel> {
        return Promise {
            (fulfill, reject) in
            let data = try model.createNSDataFor(.CREATE)
            self.RestService
                .override(crudConfigureRequestForCreate)
                .create(data)
                .success(retrieveSuccess)
                .then({ result in
                    fulfill(result)
                }, onFailure: { error in
                    reject(error)
                })
        }
    }
    
    /**
    Retrieve an object idetified by ```path```.
    
    - parameter path: An uri path to retrieve from.
    - returns: A promise of the retrieved ```RestfulModel```
    */
    public class func retrieve(path: String) -> Promise<RestfulModel> {
        return self.RestService
            .override(crudConfigureRequestForRetrieve)
            .retrieve(path)
            .then(retrieveSuccess)
    }
    
    /**
    Retrieve all objects from the server. 
    */
    public class func retrieve() -> Promise<[RestfulModel]> {
        return self.RestService
            .override(crudConfigureRequestForRetrieve)
            .retrieve()
            .then(retrieveManySuccess)
    }
    
    /**
    Retrieve a filtered list of objects from the server.
    */
    public class func retrieve(filter: [String: String]) -> Promise<[RestfulModel]> {
        return self.RestService
            .override(crudConfigureRequestForRetrieve)
            .retrieve(filter)
            .then(retrieveManySuccess)
    }
    
    /**
    Update this object's copy on the server. Calls ```path()``` to
    identify object to be destroyed.
    
     - returns: Promise of the updated object.
    */
    public func update() -> Promise<RestfulModel> {
        return Promise {
            (fulfill, reject) in
            let data = try self.createNSDataFor(.UPDATE)
            let path = self.path()
            
            RestfulModel.RestService
                .override(self.dynamicType.crudConfigureRequestForUpdate)
                .update(path, data: data)
                .success(self.dynamicType.retrieveSuccess)
                .then({ result in
                    fulfill(result)
                }, onFailure: { error in
                    reject(error)
                })
        }
    }
    
    /**
    Destroy this object's copy on the server. Calls ```path()``` to 
    identify object to be destroyed.
    
     - returns: Promise of the result.
    */
    public func destroy() -> Promise<ResponseBundle> {
        return RestfulModel.RestService
            .override(self.dynamicType.crudConfigureRequestForDestroy)
            .destroy(self.path())
    }
    
    
    // MARK: - private
    
    
    /**
    Tries to parse data returned from API into an instance of this class. Called as a
    handler for retrieve promise.
    */
    private class func retrieveSuccess(result: ResponseBundle) throws -> RestfulModel {
        guard let data = result.data else {
            throw ModelError.ServiceError(result)   //this should never happen when using services correctly
        }
        
        var jsonDict = try Utils.dictionaryFromData(data)
        jsonDict = crudAugmentRetrieve(jsonDict)
        
        return try self.init(jsonDict: jsonDict)
    }
    
    /**
    Tries to parse data returned from API into an array of instances of this class. Called
    as a handler for retrieve promise.
    */
    private class func retrieveManySuccess(result: ResponseBundle) throws -> [RestfulModel] {
        guard let data = result.data else {
            throw ModelError.ServiceError(result)   //this should never happen when using services correctly
        }
        
        let array = try Utils.arrayFromData(data)
        
        return try array
            .map({$0 as! [String:AnyObject]})
            .map(self.crudAugmentRetrieve)
            .map(self.init)
    }
    
    /**
    Encodes this object into a NSData object. Uses provided overriden 
    ```jsonPropertyNames()``` dictionary. 
    
    - returns: encoded NSData
    */
    private func createNSDataFor(method: Service.CRUDMethod) throws -> NSData {
        var dict: [String: AnyObject] = self.toJsonDictionary()
        
        switch method {
        case .CREATE:
            dict = self.dynamicType.crudAugmentCreate(dict)
        case .UPDATE:
            dict = self.dynamicType.crudAugmentUpdate(dict)
        default:
            break
        }
        
        return NSKeyedArchiver.archivedDataWithRootObject(dict)
    }
}