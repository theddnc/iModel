//
//  iModelTests.swift
//  iModelTests
//
//  Created by jzaczek on 27.12.2015.
//  Copyright © 2015 jzaczek. All rights reserved.
//

import XCTest
@testable import iModel

class ModelTests: JZTestCase {
    
    func testPropertyObserving() {
        class Testable: Model {
            dynamic var id: Int = 0
            dynamic var name: String = ""
            private override func property<T>(property: String, changedFromValue oldValue: T, toValue newValue: T) {
                XCTAssertEqual(property, "name")
                XCTAssertEqual(newValue as? String, "new name")
                XCTAssertEqual(oldValue as? String, "")
            }
        }
        
        let instance = Testable()
        instance.name = "new name"
    }
    
    func testValidation() {
        class Testable: Model {
            dynamic var id: Int = 0
            dynamic var name: String = ""
            
            class func validateId(id: Int) -> (Bool, String) {
                return (id > 0, "Id should be > 0")
            }
            
            class func validateName(name: String) -> (Bool, String) {
                return (name.characters.count > 0, "Name should be longer than 0 chars")
            }
            
            override class func debug() -> Bool {
                return true
            }
        }
        
        Testable.setValidationMethod(Testable.validateId, forField: "id")
        Testable.setValidationMethod(Testable.validateName, forField: "name")
        
        // this should fail silently
        Testable.setValidationMethod(Testable.validateName, forField: "noProperty")
        
        let instance = Testable()
        XCTAssert(instance.validationState == Model.ValidationState.Empty)
        instance.id = 10
        instance.name = "Name"
        instance.validate()
        XCTAssert(instance.validationState == Model.ValidationState.Clean)
        
        instance.id = -1
        XCTAssert(instance.validationState == Model.ValidationState.Dirty)
        XCTAssertEqual(["id"], instance.dirtyProperties)
        
        instance.name = "string"
        XCTAssert(instance.dirtyProperties.contains("id"))
        XCTAssert(instance.dirtyProperties.contains("name"))
        XCTAssert(instance.validationState == Model.ValidationState.Dirty)
        
        instance.validate()
        XCTAssert(instance.validationState == Model.ValidationState.Invalid)
        XCTAssert(instance.validationErrors.keys.contains("id"))
        XCTAssert(!instance.validationErrors.keys.contains("name"))
        
        instance.undo()
        
        XCTAssertEqual(instance.id, 10)
        XCTAssertEqual(instance.name, "Name")
    }
    
    func testClassProperties() {
        class Testable: Model {
            dynamic var id: Int = 0
            dynamic var name: String = ""
        }
        
        XCTAssert(Testable.classProperties.contains("id"))
        XCTAssert(Testable.classProperties.contains("name"))
        XCTAssertFalse(Testable.classProperties.contains("noSuchProperty"))
    }
    
}
