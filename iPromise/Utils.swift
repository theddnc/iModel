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
}