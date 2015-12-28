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

A model has it's state. Default state of the model (```Model.validationState```)
after being created is ```.Empty```.

When ```Model.validationState``` transitions from ```.Clean``` to ```.Dirty```
clean values are saved in order to be restored by calling ```undo()``` method.

Any validation logic can be provided by calling ```setValidationMethod()```. It's best
to define validation methods as ```class func``` in the ```Model``` subclass. The provided
methods will be called on ```validate()```. Returning ```(false, ...)``` from
those methods will mark a corresponding field as invalid.

**NOTE**:
 1. This class is using Swift's reflection, however ```MirrorType``` results are cached.
 2. This class is using obj-c KVO.

**When subclassing this class be aware of**:
1. If a property is not marked with ```dynamic``` keyword it will not be observed and
    hence will not influence object's ```validationState```.
2. If a property is not provided with it's default value, Swift's reflection engine
    might not work properly and your app will crash.
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
        
        /// Thrown when a subclass does not provide dafault values for its properties
        case NoDefaultsError([String])
    }
    
    /**
    Represents model validation state.
    */
    public enum ValidationState {
        
        /// Validation passed without errors
        case Clean
        
        /// Default state before any changes are made
        case Empty
        
        /// Changes made, needs to validate
        case Dirty
        
        /// Validation failed with errors
        case Invalid
    }
    
    /// will contain a reflected dictionary of class children after running first init
    internal static var classChildren: [String: Mirror.Child]?
    
    /// contains a list of class children
    internal static var classProperties: [String] {
        get {
            if self.classChildren != nil {
                return Array(self.classChildren!.keys)
            }
            else {
                return []
            }
        }
    }
    
    private var _dirtyProperties: [String] = []
    private var _validationErrors: [String: String] = [:]
    private static var _validationMethodDictionary: [String: (Any)->(Bool, String)] = [:]
    
    /// Contains values which will be restored on calling ```undo()```
    private var undoDictionary: [String: Any] = [:]
    
    /// Contains validation state of this object.
    public var validationState: ValidationState = .Empty

    
    /// Contains list of properties that were modified since last validation
    public var dirtyProperties: [String] {
        get {
            if self.validationState == .Dirty {
                return _dirtyProperties
            }
            return []
        }
    }
    
    /// Contains a dictionary of errors if this object is in ```.Invalid``` state
    public var validationErrors: [String: String] {
        get {
            if self.validationState == .Invalid {
                return _validationErrors
            }
            return [:]
        }
    }
    
    /// Initializes a model object. Creates KVO for every property.
    public override init() {
        super.init()
        
        // set up a mirror
        self.dynamicType.classChildren = Utils.dictionaryFromMirror(Mirror(reflecting: self))
        
        // create KVO for fields
        for child in self.dynamicType.classChildren!.values {
            guard let label = child.label else { continue }
            self.addObserver(self, forKeyPath: label, options: NSKeyValueObservingOptions([.New, .Old]), context: nil)
        }
    }
    
    /// Deinitializes a model object. Removes KVO for properties.
    deinit {
        
        // set up a mirror
        self.dynamicType.classChildren = Utils.dictionaryFromMirror(Mirror(reflecting: self))
        
        // remove KVO for fields
        for child in self.dynamicType.classChildren!.values {
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
        model.validationState = .Dirty
        
        _dirtyProperties = dirtyProperties
        
        // update undo dictionary
        if !undoDictionary.keys.contains(propertyKey) {
            undoDictionary[propertyKey] = fromValue
        }
        
        model.property(propertyKey, changedFromValue: fromValue, toValue: toValue)
    }
    
    /**
    Called when any property is changed. Default implementation does nothing.
    
     - parameter property: Name of the property that changed its value
     - parameter oldValue: Old value of the property
     - parameter newValue: New value of the property
    */
    public func property<T>(property: String, changedFromValue oldValue: T, toValue newValue: T) {
        if self.dynamicType.debug() == true {
            print("\(property) changed \n\tfrom: \t\(oldValue) \n\tto: \t\(newValue)")
        }
    }
    
    /**
    Override to see property changes in the console.
    */
    public class func debug() -> Bool {
        return false
    }
    
    /**
    Iterates over provided validation methods and validates properties.
    */
    public func validate() {
        self.resetValidationResult()
        
        // iterate over provided validation methods
        for (propertyName, validationMethod) in self.dynamicType._validationMethodDictionary {
            
            // ensure that property with that name exists and fail silently otherwise
            guard self.respondsToSelector(Selector(propertyName)) == true else {
                print("No property with \(propertyName) found. Make sure that this Model is correctly configured")
                continue
            }
            
            guard let propertyValue = self.valueForKey(propertyName) else { continue }
            
            let (result, message) = validationMethod(propertyValue)
            
            if result == false {
                var errors = self.validationErrors
                errors[propertyName] = message
                self.validationState = .Invalid
                _validationErrors = errors
            }
        }
        
        // no errors encountered, model seems to be Clean
        if self.validationErrors.count == 0 {
            self.validationState = .Clean
            self.undoDictionary = [:]
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
    Sets a validation method for a given field.
     
     - parameter method: Method to call when validating given field. Validation methods return
       a tuple of ```Bool``` and ```String```. First element of this tuple determines if the field is valid,
       second one contains a description of any errors.
     - parameter field: Field to be validated with the given method
    */
    public class func setValidationMethod<T>(method: (T)->(Bool, String), forField field: String) {
        _validationMethodDictionary[field] = { value in
            guard let value = value as? T else {
                return (false, "Validation method provided did not match field type")
            }
            
            return method(value)
        }
    }
    
    /**
    Resets validation result. Called before running validation.
    */
    private func resetValidationResult() {
        self.validationState = .Empty
        self._dirtyProperties = []
        self._validationErrors = [:]
    }
}