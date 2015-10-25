//
//  Model.swift
//  iPromise
//
//  Created by jzaczek on 02.11.2015.
//  Copyright © 2015 jzaczek. All rights reserved.
//

import Foundation


/**
Models are a representation of interactive data as well as logic surrounding it. 

A model will preserve it's state. Default state of the model after being created
is ```.Empty```. 

When ```Model.validationState``` transitions from ```.Clean``` to ```.Dirty```
clean values are saved in order to be restored by calling ```undo()``` method.

Any validation logic can be provided by overriding ```validationMethodDictionary()```, 
which returns a dictionary of ```[(property name): (validation method)]```. The provided
methods will be called on calling ```validate()```. Returning ```(false, "Message")``` from
those methods will mark a corresponding field as invalid.

When subclassing this class be aware of:
1. If a property is not marked with ```dynamic``` keyword it will not be observed.
2. If a property is not provided with it's default value, Swift's reflection engine
    might not work properly and your app will crash.

**TODO**:
4. Should fire events on an event bus - what events?
4a.Or should expose callbacks such as viewDidLoad - what callbacks?

7. Consider implementing local persistence in model class. Something using core data or
simple file storage - a mirror of RESTful API.
*/
public class Model: NSObject {
    /**
    Enum for model exceptions
    */
    public enum ModelError: ErrorType {
        
        /// Thrown when service does not provide expected answer
        case ServiceError(Any)
        
        /// Thrown when provided NSData cannot be parsed to an object
        case ParsingError(NSData)
    }
    
    /**
    Represents model validation state.
    */
    public enum ValidationState {
        
        /// Validation passed without errors
        case Clean
        
        /// Default state before any changes are made
        case Empty
        
        /// Changes made, needs to validate. Array contais names of changed properties.
        case Dirty([String])
        
        /// Validation failed with errors. Dict contains values returned by validation methods.
        case Invalid([String: String])
    }
    
    /// Contains values which will be restored on calling undo()
    private var undoDictionary: [String: Any] = [:]
    
    /// Contains validation state of this object.
    public var validationState: ValidationState = .Empty
    
    /// Contains list of properties that were modified since last validation
    public var dirtyProperties: [String] {
        get {
            switch self.validationState {
            case .Dirty(let values):
                return values
            default:
                return []
            }
        }
    }
    
    /// Contains a dictionary of errors if this object is in ```.Invalid``` state
    public var validationErrors: [String: String] {
        get {
            switch self.validationState {
            case .Invalid(let values):
                return values
            default:
                return [:]
            }
        }
    }
    
    /// Initializes a model object. Creates KVO for every property.
    public override init() {
        super.init()
        
        // grab a mirror
        let mirror = Mirror(reflecting: self)
        
        // create KVO for fields
        for child in mirror.children {
            guard let label = child.label else { continue }
            self.addObserver(self, forKeyPath: label, options: NSKeyValueObservingOptions([.New, .Old]), context: nil)
        }
    }
    
    /// Deinitializes a model object. Removes KVO for properties.
    deinit {
        // grab a mirror
        let mirror = Mirror(reflecting: self)
        
        // remove KVO for fields
        for child in mirror.children {
            guard let label = child.label else { continue }
            self.removeObserver(self, forKeyPath: label)
        }
    }
    
    public override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        guard
            let model = object as? Model,
            let fromValue = change?[NSKeyValueChangeOldKey],
            let toValue = change?[NSKeyValueChangeNewKey],
            let propertyKey = keyPath
        else {
            return
        }
        
        // update model state
        var dirtyProperties = model.dirtyProperties
        if !dirtyProperties.contains(propertyKey) {
            dirtyProperties.append(propertyKey)
        }
        model.validationState = .Dirty(dirtyProperties)
        
        // update undo dictionary
        if !undoDictionary.keys.contains(propertyKey) {
            undoDictionary[propertyKey] = fromValue
        }
        
        model.property(propertyKey, changedFromValue: fromValue, toValue: toValue)
    }
    
    /**
    Called when any property is changed. Default implementation prints changes.
    
     - parameter property: Name of the property that changed its value
     - parameter oldValue: Old value of the property
     - parameter newValue: New value of the property
    */
    public func property(property: String, changedFromValue oldValue: Any, toValue newValue: Any) {
        print("\(property) changed \n\tfrom: \t\(oldValue) \n\tto: \t\(newValue)")
    }
    
    /**
    Iterates over properties and runs provided validation methods.
    
    **TODO**: consider iterating over validationMethodDictionary instead - might be faster
    */
    public func validate() {
        self.resetValidationResult()
        
        // grab a mirror
        let mirror = Mirror(reflecting: self)
        
        // for every property check if there is a method to validate its value
        // and if so, run the method and save the result
        for child in mirror.children {
            guard
                let property = child.label,
                let validationMethod = self.validationMethodDictionary()[property],
                let value = self.valueForKey(property)
            else { continue }
        
            let (result, message) = validationMethod(value)
            
            if result == false {
                var errors = self.validationErrors
                errors[property] = message ?? ""
                self.validationState = .Invalid(errors)
            }
        }
        
        if self.validationErrors.count == 0 {
            self.validationState = .Clean
        }
    }
    
    public func undo() {
        for (key, value) in self.undoDictionary {
            guard let value = value as? AnyObject else { continue }
            self.setValue(value, forKey: key)
        }
        self.validate()
        self.undoDictionary = [:]
    }
    
    /**
    Returns a dictionary of validation methods. Default implementation returns an empty dict.
    
    - returns: Dictionary of methods with a following signature:
        ```
        (value: Any) -> (valid: Bool, message: String?)
        ```
    */
    public func validationMethodDictionary() -> [String: (Any)->(Bool, String?)] {
        return [:]
    }
    
    /**
    Resets validation result. Called before running validation.
    */
    private func resetValidationResult() {
        self.validationState = .Empty
    }
}


/**
**TODO**:
2. Saving and fetching should be seamlesly integrated
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
        let dict = try RestfulModel.dictionaryFromData(data)
        
        //todo throw if int value does not have a default
        for child in mirror.children.map({ $0.label ?? ""}) {
            self.setValue(dict[child], forKey: child)
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