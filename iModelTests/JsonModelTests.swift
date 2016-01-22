//
//  JsonModelTests.swift
//  iModel
//
//  Created by jzaczek on 28.12.2015.
//  Copyright © 2015 jzaczek. All rights reserved.
//

import XCTest
import iModel

class JsonModelTests: JZTestCase {
    
    func testSimpleParse() {
        class Testable: JsonModel {
            dynamic var id: Int = 0
            dynamic var name: String = ""
        }
        
        let nsData = self.data("{\"id\": 10, \"name\": \"string\"}")
        let instance = try! Testable(data: nsData)
        XCTAssertEqual(instance.id, 10)
        XCTAssertEqual(instance.name, "string")
        
        let dict = instance.toJsonDictionary()
        
        XCTAssertEqual(instance.id, dict["id"] as? Int)
        XCTAssertEqual(instance.name, dict["name"] as? String)
    }
    
    func testAdvancedParse() {
        class NestedTestable: JsonModel {
            dynamic var id: Int = 0
            dynamic var name: String = ""
        }
        
        class Testable: JsonModel {
            dynamic var id: Int = 0
            dynamic var name: String = ""
            dynamic var nullable: String?
            dynamic var floatingPoint: Float = 0.0
            dynamic var nested: NestedTestable?
            dynamic var lastOne: Int = 0
            
            override class func jsonPropertyExclusions() -> [String] {
                return ["ignore_me"]
            }
            
            override class func jsonPropertyNames() -> [String: String] {
                return ["thisIsAName": "name"]
            }
            
            override class func jsonPropertyParsingMethods() -> [String: (AnyObject) throws -> AnyObject] {
                return ["nested": NestedTestable.fromJsonDictionary]
            }
        }
        
        let nsData = self.data("{" +
                "\"id\": 10," +
                "\"thisIsAName\": \"string\"," +
                "\"floating_point\": 10.10," +
                "\"nullable\": null," +
                "\"nested\": {" +
                    "\"id\": 101," +
                    "\"name\": \"string2\"" +
                "}," +
                "\"last_one\": 69" +
            "}")
    
        measureBlock {
            for _ in 1...100 {
                let _ = try! Testable(data: nsData)
            }
        }
        
        let instance = try! Testable(data: nsData)
        
        XCTAssertEqual(instance.id, 10)
        XCTAssertEqual(instance.name, "string")
        XCTAssertEqual(instance.floatingPoint, 10.10)
        XCTAssertEqual(instance.nested?.id, 101)
        XCTAssertEqual(instance.nested?.name, "string2")
        XCTAssertEqual(instance.nullable, nil)
        XCTAssertEqual(instance.lastOne, 69)
        
        let dict = instance.toJsonDictionary()
        XCTAssertEqual((dict["nested"] as? [String:AnyObject])?["id"] as? Int, 101)
        XCTAssertEqual((dict["nested"] as? [String:AnyObject])?["name"] as? String, "string2")
    }
    
    func testSerializeHandles() {
        class Testable: JsonModel {
            dynamic var id: Int = 0
            dynamic var name: String = ""
            
            override class func jsonBeforeDeserialize(data: [String: AnyObject?]) -> [String: AnyObject?] {
                var dict = data;
                dict["name"] = (data["name"] as? String ?? "") + " hehe"
                return dict
            }
            
            override class func jsonAfterSerialize(data: [String: AnyObject?]) -> [String: AnyObject?] {
                var dict = data
                dict["additional_key"] = "additional_value"
                return dict
            }
        }
        
        let nsData = self.data("{\"id\": 10, \"name\": \"string\"}")
        
        let instance = try! Testable(data: nsData)
        
        XCTAssertEqual(instance.id, 10)
        XCTAssertEqual(instance.name, "string hehe")
        
        let dict = instance.toJsonDictionary()
        
        XCTAssertEqual(dict["name"] as? String, "string hehe")
        XCTAssertEqual(dict["additional_key"] as? String, "additional_value")
    }
}
