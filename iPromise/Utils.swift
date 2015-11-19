//
//  Utils.swift
//  iPromise
//
//  Created by jzaczek on 13.11.2015.
//  Copyright © 2015 jzaczek. All rights reserved.
//

import Foundation

struct Utils {
    static func toCamelCase(snakeCaseString: String) -> String {
        return snakeCaseString.characters
            .split("_")
            .map(String.init)
            .reduce("", combine: {
                (result: String, nextString: String) in
                if result == "" {
                    return nextString.lowercaseString
                }
                return "\(result)\(nextString.capitalizedString)"
            })
    }
    
    /**
    Returns a dictionary that was parsed from a JSON-formatted NSData.
    */
    static func dictionaryFromData(data: NSData) throws -> [String: AnyObject] {
        guard let parsedObject: [String: AnyObject] = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) as? [String:AnyObject] else {
            throw Model.ModelError.ParsingError(data)
        }
        
        return parsedObject
    }
    
    /**
    
    */
    static func arrayFromData(data: NSData) throws -> [AnyObject] {
        guard let parsedObject: [AnyObject] = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) as? [AnyObject] else {
            throw Model.ModelError.ParsingError(data)
        }
        
        return parsedObject
    }
    
    static func dictionaryFromMirror(mirror: Mirror) -> [String: Mirror.Child] {
        var dict: [String: Mirror.Child] = [:]
        for child in mirror.children {
            if let key = child.label {
                dict.updateValue(child, forKey: key)
            }
        }
        
        return dict
    }
    
    static func dictionaryNilsToNSNull(dict: [String: AnyObject?]) -> [String: AnyObject] {
        var returnDictionary: [String: AnyObject] = [:]
        for (key, value) in dict {
            returnDictionary.updateValue(value ?? NSNull(), forKey: key)
        }
        return returnDictionary
    }
}