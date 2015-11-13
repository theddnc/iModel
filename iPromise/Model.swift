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
1. If a property is not marked with ```dynamic``` keyword it will not be observed and
    hence will not influence object's ```validationState```.
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
    
    /// Contains values which will be restored on calling ```undo()```
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
    Iterates over provided validation methods and validates properties.
    */
    public func validate() {
        self.resetValidationResult()
        
        // iterate over provided validation methods
        for (propertyName, validationMethod) in self.validationMethodDictionary() {
            
            // ensure that property with that name exists and fail silently otherwise
            guard self.respondsToSelector(Selector(propertyName)) == true else {
                print("No property with \(propertyName) found. Make sure that this Model is correctly configured")
                continue
            }
            
            guard let propertyValue = self.valueForKey(propertyName) else { continue }
            
            let (result, message) = validationMethod(propertyValue)
            
            if result == false {
                var errors = self.validationErrors
                errors[propertyName] = message ?? ""
                self.validationState = .Invalid(errors)
            }
        }
        
        // no errors encountered, model seems to be Clean
        if self.validationErrors.count == 0 {
            self.validationState = .Clean
        }
    }
    
    /**
    Restores model's property values to last Clean or Empty validation states.
    */
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