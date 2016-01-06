//
//  RestfulModelTests.swift
//  iModel
//
//  Created by jzaczek on 28.12.2015.
//  Copyright © 2015 jzaczek. All rights reserved.
//

import XCTest
import iModel
import iPromise
import iService
import Nocilla

class Testable: RestfulModel {
    dynamic var key: String = ""
    dynamic var id: Int = 0
    
    override class func urlOfService() -> NSURL {
        return NSURL(string: "https://mock.com/resource")!
    }
    
    override func path() -> String {
        return "\(self.id)"
    }
}

class RestfulModelTests: JZTestCase {
    
    var baseUrl = "https://mock.com"
    var resource = "resource"
    
    func testRetrieve() {
        stubRequest("GET", "https://mock.com/resource/1?")
            .andReturn(200)
            .withBody("{\"key\":\"value\", \"id\": 1}")
        
        expect { te in
            Testable.retrieve("1").then({ (result: Testable) in
                XCTAssertEqual(result.id, 1)
                XCTAssertEqual(result.key, "value")
                te.fulfill()
            })
        }
    }
    
    func testRetrieveMany() {
        stubRequest("GET", "https://mock.com/resource/?")
            .andReturn(200)
            .withBody("[{\"key\":\"value0\", \"id\": 1}, {\"key\":\"value1\", \"id\": 2}]")
        
        expect { te in
            Testable.retrieve().then({ (result: [Testable]) in
                for (i, item) in result.enumerate() {
                    XCTAssertEqual(item.id, i + 1)
                    XCTAssertEqual(item.key, "value\(i)")
                }
                
                te.fulfill()
            })
        }
    }
    
    func testRetrieveFilter() {
        stubRequest("GET", "https://mock.com/resource/?id=1&")
            .andReturn(200)
            .withBody("[{\"key\":\"value\", \"id\": 1}]")
        
        expect { te in
            Testable.retrieve(["id": "1"]).then({ (result: [Testable]) in
                XCTAssertEqual(result[0].id, 1)
                XCTAssertEqual(result[0].key, "value")
                
                te.fulfill()
            })
        }
    }
    
    func testCreate() {
        stubRequest("POST", "https://mock.com/resource/?")
            .andReturn(201)
            .withBody("{\"key\":\"value\", \"id\": 1}")
        
        expect { te in
            let model = Testable()
            model.id = 1
            model.key = "value"
            
            Testable.create(model).then({ result in
                XCTAssertEqual(result.id, model.id)
                XCTAssertEqual(result.key, model.key)
                
                te.fulfill()
            })
        }
    }
    
    func testUpdate() {
        stubRequest("GET", "https://mock.com/resource/1?")
            .andReturn(200)
            .withBody("{\"key\":\"value\", \"id\": 1}")
        
        stubRequest("PUT", "https://mock.com/resource/1?")
            .andReturn(200)
            .withBody("{\"key\":\"new value\", \"id\": 1}")
        
        expect { te in
            Testable.retrieve("1").then({ (result: Testable) -> Promise<Testable> in
                result.key = "new value"
                
                return result.update()
            }).then({ result in
                XCTAssertEqual(result.key, "new value")
                te.fulfill()
            })
        }
    }
    
    func testDestroy() {
        stubRequest("DELETE", "https://mock.com/resource/1?")
            .andReturn(204)
        
        expect { te in
            let testable = Testable()
            testable.id = 1
            testable.key = "value"
            
            testable.destroy().then({ result in
                XCTAssertEqual(result.response?.statusCode, 204)
                te.fulfill()
            })
        }
    }
}
