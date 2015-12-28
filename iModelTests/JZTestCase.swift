//
//  JZTestCase.swift
//  iService
//
//  Created by jzaczek on 20.12.2015.
//  Copyright © 2015 jzaczek. All rights reserved.
//

import XCTest
import Nocilla

class JZTestCase: XCTestCase {
    
    override func setUp() {
        super.setUp()
        LSNocilla.sharedInstance().start()
    }
    
    override func tearDown() {
        LSNocilla.sharedInstance().clearStubs()
        LSNocilla.sharedInstance().stop()
        super.tearDown()
    }
    
    internal func str(data: NSData?) -> String? {
        guard let data = data else {
            return nil
        }
        return NSString(data: data, encoding: NSUTF8StringEncoding) as? String
    }
    
    internal func data(str: String) -> NSData {
        return str.dataUsingEncoding(NSUTF8StringEncoding)!
    }
    
    internal func expect(testClosure: (XCTestExpectation) -> Void) -> Void {
        let testExpectation = expectationWithDescription("Test expectation")
        
        testClosure(testExpectation)
        
        waitForExpectationsWithTimeout(1000, handler: {
            error in
            XCTAssertNil(error, "Error")
        })
    }
}
