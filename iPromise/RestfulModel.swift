//
//  RestfulModel.swift
//  iPromise
//
//  Created by jzaczek on 13.11.2015.
//  Copyright © 2015 jzaczek. All rights reserved.
//

import Foundation

/**
TODO INTRO

JSON files are parsed using following algorithm:

For each key-value pair:
0. Check if this property should be ignored by using ```jsonPropertyExclusions```. 
    If so, *go to next pair.*

1. Check if there is a translation provided in ```jsonPropertyNames```. If so,
    check if the object has a property with the given name. If so, this is the property
    name for this key-value pair - *go to 4.*
    
    *Otherwise, continue.*

2. If the json property name is in snake_case convert it's name to camelCase and continue.
    
    *Otherwise, continue.*

3. If the json property name is in camelCase check if this class has a property with that name.
    If so, *go to 4.*
    
    *Otherwise, fail silently and go to next pair*.

4. **TODO**: Check if there is a parsing method provided in ```jsonPropertyParsingMethods```
    and if so, use that method to parse this key-value pair. *Go to next pair.*
    
    Otherwise assign value from json to that property. *Go to next pair.*


**TODO**:
1. Saving and fetching should be seamlesly integrated
2. Integrate service realms
*/
public class RestfulModel: Model {
    
    /// Service for fetching and saving data
    private static var _restService: Service?
    
    /// Service for fetching and saving data
    private static var RestService: Service {
        get {
            if _restService == nil {
                _restService = Service(serviceUrl: self.urlOfService())
            }
            return _restService!
        }
    }
    
    /// Initializes an object from provided NSData. Assumes that NSData contains
    /// a JSON file.
    required public init(data: NSData) throws {
        super.init()
        
        let mirror = Mirror(reflecting: self)
        let classProperties: [String] = mirror.children.map( {$0.label ?? ""} )
        let jsonValues = try RestfulModel.dictionaryFromData(data)
        let propertyExclusions = self.classForCoder.jsonPropertyExclusions()
        let propertyNames = self.classForCoder.jsonPropertyNames()
        
        for (key, value) in jsonValues {
            if propertyExclusions.contains(key) {
                continue    // we should ignore this key-value pair
            }
            if let propertyName = RestfulModel.getPropertyNameFromKey(key, propertyNames: propertyNames, classProperties: classProperties) {
                self.setValue(value, forKey: propertyName)
            }
            else {
                continue
            }
        }
    }
    
    public override init() {
        super.init()
    }
    
    /**
    Returns a NSURL of a service that should manage persitstence of this class.
    
    - returns: A NSURL of REST service.
    */
    public class func urlOfService() -> NSURL {
        fatalError("This method should be overriden in order to use RESTful functionalities")
    }
    
    public func path() -> String {
        fatalError("This method needs to be overriden to seamlessly update and delete objects")
    }
    
    /**
    Returns an array of ```[(json property name)]``` that will be ignored while parsing.
    */
    public class func jsonPropertyExclusions() -> [String] {
        return []
    }
    
    /**
    Returns a dictionary containing pairs of ```[(json property name): (model property name)]```
    These values are used to override default property mapping when parsing JSON files.
    */
    public class func jsonPropertyNames() -> [String: String] {
        return [:]
    }
    
    public class func jsonPropertyParsingMethods() -> [String: (AnyObject) -> AnyObject] {
        return [:]
    }
    
    /**
    Fires a create request.
    
    - parameter model: Model to be creted in the persistend store of the backend.
    - returns: A promise of the backend's response
    */
    public class func create(model: RestfulModel) -> Promise {
        return Promise {
            (fulfill, reject) in
            let data = try model.createNSData()
            
            fulfill(self.RestService.create(data).success(retrieveSuccess))
        }
    }
    
    /**
    Fires a retrieve request.
    
    - parameter path: An uri path to retrieve from.
    - returns: A promise of the retrieved ```RestfulModel```
    */
    public class func retrieve(path: String) -> Promise {
        return self.RestService.retrieve(path).success(retrieveSuccess)
    }
    
    //TODO: fix
    public class func retrieve() -> Promise {
        return self.RestService.retrieve().success(retrieveSuccess)
    }
    
    public func retrieve(filter: [String: String]) -> Promise {
        return Promise.fulfill(1)
    }
    
    public func update() -> Promise {
        return Promise {
            (fulfill, reject) in
            let data = try self.createNSData()
            let path = self.path()
            
            fulfill(RestfulModel.RestService.update(path, data: data))
        }
    }
    
    public func destroy() -> Promise {
        return RestfulModel.RestService.destroy(self.path())
    }
    
    /**
    Tries to parse data returned from API into an instance of this class.
    */
    private class func retrieveSuccess(result: Any) throws -> Any {
        guard let (data, _) = result as? (NSData, NSURLResponse) else {
            throw ModelError.ServiceError(result)
        }
        
        return try self.init(data: data)
    }
    
    /**
    Returns a dictionary that was parsed from a JSON-formatted NSData.
    */
    private class func dictionaryFromData(data: NSData) throws -> [String: AnyObject] {
        guard let parsedObject: [String: AnyObject] = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) as? [String:AnyObject] else {
            throw ModelError.ParsingError(data)
        }
        
        return parsedObject
    }
    
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
    Encodes this object into a NSData object.
    */
    private func createNSData() throws -> NSData {
        let mirror = Mirror(reflecting: self)
        var dict: [String: AnyObject] = [:]
        for child in mirror.children {
            if child.label == "id" {
                continue
            }
            dict[child.label!] = self.valueForKey(child.label!)
        }
        
        return NSKeyedArchiver.archivedDataWithRootObject(dict)
    }
}