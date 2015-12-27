//
//  JsonModel.swift
//  iPromise
//
//  Created by jzaczek on 16.11.2015.
//  Copyright © 2015 jzaczek. All rights reserved.
//

import Foundation


/**
```JsonModel``` extends ```Model``` with JSON files parsing utilities. Basic usage of
this class will be to name all properties using keys from the corresponding json file.

**NOTE**: this class uses NSJSONSerialization. Json nulls are deserialized into ``NSNull``

To use more advanced configuration override the following methods:

1. ```jsonPropertyExclusions``` - excludes a list of JSON keys from parsing
2. ```jsonPropertyNames``` - provides a map which links JSON key to object's property
name
3. ```jsonPropertyParsingMethods``` - provides methods which override default parsing
logic
4. ```jsonBeforeDeserialize``` - modify json dictionary before parsing it into an 
instance of ```JsonModel```
5. ```jsonAfterDeserialize``` - modify json dictionary which is a result of deserialization
of an instance of ```JsonModel```
*/
public class JsonModel: Model {
    
    /// ```ErrorType``` for this ```JsonModel```
    enum JsonModelError: ErrorType {
        
        /// Thrown when anyobject given to the ```fromJsonDictionary``` is not a dictionary
        case ParsingError(String, AnyObject)
    }
        
    /// contains a list of keys excluded from parsing
    private static var propertyExclusions: [String] = JsonModel.jsonPropertyExclusions()
    
    /// contains a dictionary that maps json keys to property names
    private static var propertyNames: [String: String] = JsonModel.jsonPropertyNames()
    
    /// contains a dictionary that provides parsing methods for json keys
    private static var propertyParsingMethods: [String: (AnyObject) throws -> AnyObject] = JsonModel.jsonPropertyParsingMethods()
    
    
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
    required public init(var jsonDict: [String: AnyObject]) throws {
        super.init()
    
        jsonDict = Utils.dictionaryNilsToNSNull(self.dynamicType.jsonBeforeDeserialize(jsonDict))
        
        for (key, value) in jsonDict {
            if self.dynamicType.propertyExclusions.contains(key) {
                continue
            }
            
            if let propertyName = self.dynamicType.getPropertyNameFromKey(key) {
                try self.setValue(value, atKey: key, forPropertyNamed: propertyName)
            }
            else {
                print("Unable to find class property for provided key: \"\(key)\".")
                continue
            }
        }
    }
    
    /**
    Initialize a ```JsonModel``` from NSData containing JSON file. 
    */
    public convenience init(data: NSData) throws {
        let dict = try Utils.dictionaryFromData(data)
        try self.init(jsonDict: dict)
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
    Called at the beginning of object initialization from json dictionary. Override to modify
    any data.
    */
    public class func jsonBeforeDeserialize(data: [String: AnyObject?]) -> [String: AnyObject?] {
        return data
    }
    
    /**
    Called at the end of object deserialization. Override to modify any data.
    */
    public class func jsonAfterSerialize(data: [String: AnyObject?]) -> [String: AnyObject?] {
        return data
    }
    
    /**
    Creates a json dictionary from this object. If encounters properties which are
    JsonModels calls this method on them as well.
    
     - returns: ```[String: AnyObject]``` dictionary that can be encoded into 
        ```NSData``` and embedded as the body of an ```NSURLRequest```
    */
    public func toJsonDictionary() -> [String: AnyObject] {
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
                    //if value for this key is JsonModel, deserialize it
                    dict[key] = self.valueForKey(label)?.toJsonDictionary()
                }
                else if self.valueForKey(label) == nil {
                    //if value for this key is nil, set NSNull()
                    dict[key] = NSNull()
                }
                else {
                    //save the correct value at the correct key
                    dict[key] = self.valueForKey(label)
                }
            }
        }
        
        dict = Utils.dictionaryNilsToNSNull(self.dynamicType.jsonAfterSerialize(dict))
        
        return dict
    }
    
    /**
    Returns an instance of this class parsed from a given jsonDictionary. This method
    should be used as one of ```jsonPropertyParsingMethods``` when deserializing nested
    models. 
    
    Example:
    
    ```
    class Address: JsonModel { /*...*/ }
    
    class User: JsonModel {
        //...
        var address: Address = Address()
        
        //...
    
        public override class func jsonPropertyParsingMethods() -> [String: (AnyObject) throws -> AnyObject {
            return ["address": Address.fromJsonDictionary]
        }
    }
    ```
    */
    public class func fromJsonDictionary(jsonDict: AnyObject) throws -> JsonModel {
        if let dict = jsonDict as? [String: AnyObject] {
            return try self.init(jsonDict: dict)
        }
        else {
            throw JsonModelError.ParsingError("", jsonDict)
        }
    }
    
    /**
    For a given json key, property map and class property names, get a correct
    property name.
    
    - parameter key: JSON dictionary key, that will be mapped to a property name
    
    - returns: Correctly mapped property name, or nil, if a property couldn't be found on object
    */
    private class func getPropertyNameFromKey(key: String) -> String? {
        if self.propertyNames.keys.contains(key) && self.classProperties.contains(self.propertyNames[key]!){
            return self.propertyNames[key]!
        }
        
        if key.containsString("_") && self.classProperties.contains(Utils.toCamelCase(key)) {
            return Utils.toCamelCase(self.propertyNames[key]!)
        }
        
        if self.classProperties.contains(key) {
            return key
        }
        
        return nil
    }
    
    /**
    Set a property to a value located a the given key
    
     - parameter value: a value from parsed json
     - parameter key: key corresponding to that value
     - parameter propertyName: name of the property to set the value of
     
     - throws ```JsonModelError.ParsingError(key, value)```
    */
    private func setValue(value: AnyObject, atKey key: String, forPropertyNamed propertyName: String) throws {
        if value is NSNull && Mirror(reflecting: self.dynamicType.classChildren![key]).displayStyle == .Optional {
            self.setValue(nil, forKey: propertyName)
        }
        else if let parsingMethod = self.dynamicType.propertyParsingMethods[key] {
            do {
                let parsedValue = try parsingMethod(value)
                self.setValue(parsedValue, forKey: propertyName)
            }
            catch _ as JsonModelError {
                throw JsonModelError.ParsingError(key, value)
            }
        }
        else {
            self.setValue(value, forKey: propertyName)
        }
    }
}