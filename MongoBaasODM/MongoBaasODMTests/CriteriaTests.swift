//
//  CriteriaTests.swift
//  MongoBaasODM
//
//  Created by Yanai Rozenberg on 24/05/2017.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import XCTest
@testable import MongoBaasODM
import MongoExtendedJson
import MongoDB

class CriteriaTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    //MARK: Criterias
    func testCriteriaGreaterThan() {
        let isGreaterThan: Criteria = .greaterThan(field: "age", value: 30)
        
        let isGreaterThanDoc = isGreaterThan.asDocument
        XCTAssertEqual((isGreaterThanDoc["age"] as? Document)?["$gt"] as? Int , 30)
    }
    
    func testCriteriaEquals() {
        let isEquals: Criteria = .equals(field: "age", value: 30)
        
        let isEqualsDoc = isEquals.asDocument
        XCTAssertEqual((isEqualsDoc["age"] as? Document)?["$eq"] as? Int , 30)
    }
    
    func testCriteriaAnd() {
        let ageInput = 30
        let inputField1 = "age"
        let inputField2 = "color"
        let colorInput = "green"
        let andField: Criteria = .and([.greaterThan(field: inputField1, value: ageInput), .equals(field: inputField2, value: colorInput)])
        
        
        let andFieldDoc = andField.asDocument
        
        let andArrayDoc = andFieldDoc["$and"] as? BsonArray
        let firstConditionDoc = andArrayDoc?[0] as? Document
        let secondConditionDoc = andArrayDoc?[1] as? Document
        XCTAssertEqual((firstConditionDoc?[inputField1] as? Document)?["$gt"] as? Int , ageInput)
        XCTAssertEqual((secondConditionDoc?[inputField2] as? Document)?["$eq"] as? String , colorInput)
    }
    
    func testCriteriaOr() {
        let orField: Criteria = .or([.greaterThan(field: "age", value: 30), .equals(field: "color", value: "green")])
        
        let orFieldDoc = orField.asDocument
        let orArrayDoc = orFieldDoc["$or"] as? BsonArray
        let firstConditionDoc = orArrayDoc?[0] as? Document
        let secondConditionDoc = orArrayDoc?[1] as? Document
        XCTAssertEqual((firstConditionDoc?["age"] as? Document)?["$gt"] as? Int , 30)
        XCTAssertEqual((secondConditionDoc?["color"] as? Document)?["$eq"] as? String , "green")
    }
    
    func testCriteriaGreaterThanOrEqual() {
        let isGreaterThanOrEqual: Criteria = .greaterThanOrEqual(field: "age", value: 30)
        
        let isGreaterThanOrEqualDoc = isGreaterThanOrEqual.asDocument
        XCTAssertEqual((isGreaterThanOrEqualDoc["age"] as? Document)?["$gte"] as? Int , 30)
    }
    
    func testCriteriaLessThan() {
        let isLessThan: Criteria = .lessThan(field: "age", value: 30)
        
        let isLessThanDoc = isLessThan.asDocument
        XCTAssertEqual((isLessThanDoc["age"] as? Document)?["$lt"] as? Int , 30)
    }
    
    func testCriteriaLessThanOrEqual() {
        let isLessThanOrEqual: Criteria = .lessThanOrEqual(field: "age", value: 30)
        
        let isLessThanOrEqualDoc = isLessThanOrEqual.asDocument
        XCTAssertEqual((isLessThanOrEqualDoc["age"] as? Document)?["$lte"] as? Int , 30)
    }
    
    func testCriteriaNotEqual() {
        let notEqual: Criteria = .notEqual(field: "age", value: 30)
        
        let notEqualDoc = notEqual.asDocument
        XCTAssertEqual((notEqualDoc["age"] as? Document)?["$ne"] as? Int , 30)
    }
    
    func testCriteriaIn() {
        let inSelector: Criteria = .in(field: "age", values:[30, 35, 40])
        
        let inDoc = inSelector.asDocument
        let bsonArray = (inDoc["age"] as? Document)?["$in"] as? BsonArray
        
        XCTAssertEqual(bsonArray?[0] as? Int, 30)
        XCTAssertEqual(bsonArray?[1] as? Int, 35)
        XCTAssertEqual(bsonArray?[2] as? Int, 40)
    }
    
    func testCriteriaNin() {
        let ninSelector: Criteria = .nin(field: "age", values:[30, 35, 40])
        
        let ninDoc = ninSelector.asDocument
        let bsonArray = (ninDoc["age"] as? Document)?["$nin"] as? BsonArray
        
        XCTAssertEqual(bsonArray?[0] as? Int, 30)
        XCTAssertEqual(bsonArray?[1] as? Int, 35)
        XCTAssertEqual(bsonArray?[2] as? Int, 40)
    }
    
    func testCriteriaNot() {
        let notOperator: Criteria = .not(.greaterThan(field: "age", value: 30))
        
        let notDocument = notOperator.asDocument
        XCTAssertEqual(((notDocument["age"] as? Document)?["$not"] as? Document)?["$gt"] as? Int , 30)
    }
    
    func testCriteriaNor() {
        let norField: Criteria = .nor([.greaterThan(field: "age", value: 30), .equals(field: "color", value: "green")])
        
        let norFieldDoc = norField.asDocument
        let norArrayDoc = norFieldDoc["$nor"] as? BsonArray
        let firstConditionDoc = norArrayDoc?[0] as? Document
        let secondConditionDoc = norArrayDoc?[1] as? Document
        XCTAssertEqual((firstConditionDoc?["age"] as? Document)?["$gt"] as? Int , 30)
        XCTAssertEqual((secondConditionDoc?["color"] as? Document)?["$eq"] as? String , "green")
    }
    
    func testCriteriaText() {
        let textCriteria: Criteria = .text(search: "Find Me", language: "en", caseSensitive: true, diacriticSensitive: false)
        
        let textCriteriaDoc = textCriteria.asDocument
        let textDocumentParams = textCriteriaDoc["$text"] as? Document
        XCTAssertEqual(textDocumentParams?["$caseSensitive"] as? Bool, true)
        XCTAssertEqual(textDocumentParams?["$search"] as? String, "Find Me")
        XCTAssertEqual(textDocumentParams?["$diacriticSensitive"] as? Bool, false)
        XCTAssertEqual(textDocumentParams?["$language"] as? String, "en")
    }
    
    func testCriteriaExists() {
        let existsCriteria: Criteria = .exists(field: "age", value: false)
        
        let existsCriteriaDoc = existsCriteria.asDocument
        XCTAssertEqual((existsCriteriaDoc["age"] as? Document)?["$exists"] as? Bool , false)
    }
    
    //Criteria operators
    func testLogicalNot() {
        let existsCriteria: Criteria = .exists(field: "age", value: false)
        let notCriteria = !existsCriteria
        
        let notExistsCriteriaDoc = notCriteria.asDocument
        XCTAssertEqual(((notExistsCriteriaDoc["age"] as? Document)?["$not"] as? Document)?["$exists"] as? Bool , false)
    }
    
    func testLogicalAnd() {
        let ageInput = 30
        let inputField1 = "age"
        let inputField2 = "color"
        let colorInput = "green"
        let firstCriteria: Criteria = .greaterThan(field: inputField1, value: ageInput)
        let secondCriteria: Criteria = .equals(field: inputField2, value: colorInput)
        let andCriteria: Criteria = firstCriteria && secondCriteria
        
        
        let andCriteriaDoc = andCriteria.asDocument
        
        let andArrayDoc = andCriteriaDoc["$and"] as? BsonArray
        let firstConditionDoc = andArrayDoc?[0] as? Document
        let secondConditionDoc = andArrayDoc?[1] as? Document
        XCTAssertEqual((firstConditionDoc?[inputField1] as? Document)?["$gt"] as? Int , ageInput)
        XCTAssertEqual((secondConditionDoc?[inputField2] as? Document)?["$eq"] as? String , colorInput)
    }
    
    func testLogicalOr() {
        let ageInput = 30
        let inputField1 = "age"
        let inputField2 = "color"
        let colorInput = "green"
        let firstCriteria: Criteria = .greaterThan(field: inputField1, value: ageInput)
        let secontCriteria: Criteria = .equals(field: inputField2, value: colorInput)
        let orField: Criteria = firstCriteria || secontCriteria
        
        let orFieldDoc = orField.asDocument
        let orArrayDoc = orFieldDoc["$or"] as? BsonArray
        let firstConditionDoc = orArrayDoc?[0] as? Document
        let secondConditionDoc = orArrayDoc?[1] as? Document
        XCTAssertEqual((firstConditionDoc?[inputField1] as? Document)?["$gt"] as? Int , ageInput)
        XCTAssertEqual((secondConditionDoc?[inputField2] as? Document)?["$eq"] as? String , colorInput)
    }

}
