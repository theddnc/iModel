//
//  JsonModel.swift
//  iPromise
//
//  Created by jzaczek on 16.11.2015.
//  Copyright © 2015 jzaczek. All rights reserved.
//

import Foundation


/**
 - initialized from json
 - serializable to json
*/
public class JsonModel: Model {
    
    enum JsonModelError: ErrorType {
        case ParsingError(AnyObject)
    }
    
    
    /**
    Parses json dictionary into an instance of this class.
    
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
    
    4. Check if there is a parsing method provided in ```jsonPropertyParsingMethods```
    and if so, use that method to parse this key-value pair. *Go to next pair.*
    
    Otherwise assign value from json to that property. *Go to next pair.*
    */
    required public init(jsonDict: [String: AnyObject]) throws {
        super.init()
        
        let mirror = Mirror(reflecting: self)
        let classChildren: [String: Mirror.Child] = Utils.dictionaryFromMirror(mirror)
        //let classChildren: [Mirror.Child] = mirror.children.map{ $0 }
        let classProperties: [String] = Array(classChildren.keys)
        let propertyExclusions = self.dynamicType.jsonPropertyExclusions()
        let propertyNames = self.dynamicType.jsonPropertyNames()
        let propertyParsingMethods = self.dynamicType.jsonPropertyParsingMethods()
        
        for (key, value) in jsonDict {
            if propertyExclusions.contains(key) {
                continue    // we should ignore this key-value pair
            }
            
            if let propertyName = self.dynamicType.getPropertyNameFromKey(key, propertyNames: propertyNames, classProperties: classProperties) {
                if let parsedValue = try propertyParsingMethods[key]?(value) {
                    self.setValue(parsedValue, forKey: propertyName)
                }
                else {
                    self.setValue(value, forKey: propertyName)
                }
            }
            else {
                print("Unable to find class property for provided key: \"\(key)\".")
                continue
            }
        }
    }
    
    public override init() {
        super.init()
    }
    
    /**
    Returns an array of ```[(json property name)]``` that will be ignored while parsing.
    
    - returns: an array of json keys to be ignored while parsing
    */
    public class func jsonPropertyExclusions() -> [String] {
        return []
    }
    
    /**
    Returns a dictionary containing pairs of ```[(json property name): (model property name)]```
    These values are used to override default property mapping when parsing JSON files.
    
    - returns: a map of json keys and class properties
    */
    public class func jsonPropertyNames() -> [String: String] {
        return [:]
    }
    
    /**
    Returns a dictionary which contains methods for parsing given properties. Indexes are JSON keys.
    These methods are useful when overriding default parsing behaviour, which is to call
    ```setValue:forKey:```. For example, if the api returns an array of object ids, they
    can be mapped to real objects in your application. Or, if the api returns an array of
    JSON objects, a RestfulModel.init(NSData) might be passed as the method for that key.
    
    - returns: dictionary of property parsing methods with a following signature:
    ```(AnyObject) -> AnyObject```
    */
    public class func jsonPropertyParsingMethods() -> [String: (AnyObject) throws -> AnyObject] {
        return [:]
    }
    
    /**
    
    */
    public func createJsonDictionary() -> [String: AnyObject] {
        let mirror = Mirror(reflecting: self)
        var dict: [String: AnyObject] = [:]
        let propertyNames = self.dynamicType.jsonPropertyNames()
        
        for child in mirror.children {
            if let label = child.label {
                let key: String = propertyNames
                    .filter({ $0.1 == label})           //get all entries that match this property name
                    .map({ $0.0 })                      //we only need keys, which correspond to json properties
                    .first ?? label                     //and we only need the first one or, if there isn't one, the property name itself
                
                if self.valueForKey(label) is JsonModel {
                    dict[key] = self.valueForKey(label)?.createJsonDictionary()
                }
                else {
                    dict[key] = self.valueForKey(label)     //save the value at the correct key
                }
            }
        }
        
        return dict
    }
    
    public class func fromJsonDictionary(jsonDict: AnyObject) throws -> JsonModel {
        if let dict = jsonDict as? [String: AnyObject] {
            return try self.init(jsonDict: dict)
        }
        else {
            throw JsonModelError.ParsingError(jsonDict)
        }
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
}