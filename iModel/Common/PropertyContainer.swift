//
//  PropertyContainer.swift
//  iModel
//
//  Created by jzaczek on 22.01.2016.
//  Copyright © 2016 jzaczek. All rights reserved.
//

import Foundation

/**
 This class provides means to save reflection results for each of 
 Model derived classes. It was introduces in order to optimize
 parsing process, i.e. not call ```Mirror(reflecting: ...)``` 
 every time when creating an object.
*/
internal class PropertyContainer {
    /// Contains all defined ```PropertyContainer``` instances
    private static var propertyContainers: [String: PropertyContainer] = [:]
    
    /// Contains a map of property names and ```Mirror.Child```
    private var _classChildren: [String: Mirror.Child]
    
    /// Contains a map of property names and ```Mirror.Child```
    /// Read-only
    internal var classChildren: [String: Mirror.Child] {
        get {
            return _classChildren
        }
    }
    
    /// Contains a list of property names
    private var _classProperties: [String]?
    
    /// Contains a list of property names
    /// Read-only
    internal var classProperties: [String] {
        get {
            if _classProperties == nil {
                _classProperties = Array(_classChildren.keys)
            }
            
            return _classProperties ?? []
        }
    }
    
    /// Initializes single ```PropertyContainer``` from a ```Model```
    private init<T: Model>(object: T) {
        self._classChildren = self.dynamicType.dictionaryFromMirror(Mirror(reflecting: object))
    }
    
    /// Returns a ```PropertyContainer``` for the given Model instance
    internal class func get<T: Model>(object: T) -> PropertyContainer {
        let key = "\(object.dynamicType)"
        if !self.propertyContainers.keys.contains(key) {
            self.propertyContainers.updateValue(PropertyContainer(object: object), forKey: key)
        }
        
        return self.propertyContainers[key]!
    }
    
    /// Takes a ```Mirror``` and returns a map of its children indexed by their labels
    /// In other words: returns a map of property name - property description
    private class func dictionaryFromMirror(mirror: Mirror) -> [String: Mirror.Child] {
        var dict: [String: Mirror.Child] = [:]
        for child in mirror.children {
            if let key = child.label {
                dict.updateValue(child, forKey: key)
            }
        }
        
        return dict
    }
}
