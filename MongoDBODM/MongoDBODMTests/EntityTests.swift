//
//  EntityTests.swift
//  MongoBaasODM
//
//  Created by Ofir Zucker on 28/05/2017.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import XCTest
@testable import MongoDBODM
import ExtendedJson
import MongoDBService
@testable import StitchCore

class EntityTests: XCTestCase {
    
    static let serviceName = "serviceName"
    static let dbName = "db"
    static let collectionName = "collection"
    
    static let name = "name"
    static let grade = "grade"
    static let report = "report"
    static let teachers = "teachers"
    static let lunchBox = "lunchBox"
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        Report.registerClass(entityMetaData: ReportMetaDataImp())
        Teacher.registerClass(entityMetaData: TeacherMetaDataImp())
        Student.registerClass(entityMetaData: StudentMetaDataImp())
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // MARK: - Tests Root
    
    // Test a root mongoDB entity Save operation
    func testRootEntitySave() {
        let expectationResult = self.expectation(description: "save call closure should be executed")
        let expectationCollection = self.expectation(description: "collection execution should be executed")
        
        let mongoDBClient = TestMongoDBClient()
        
        let student = Student(mongoDBClient: mongoDBClient)
        student.name = EntityTests.name
        
        mongoDBClient.database.collection.expectedMethod = .insert
        mongoDBClient.database.collection.expectedInputBlock = { document in
            
            let name = document[EntityTests.name] as! String
            XCTAssertEqual(name, student.name!)
            expectationCollection.fulfill()
        }
        
        student.save().response { response in
            XCTAssertNotNil(student.objectId!)
            expectationResult.fulfill()
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    // Test a root mongoDB entity Save operation on an entity which has not been registered (should return an error)
    func testRootEntitySaveUnregistered() {
        let expectation = self.expectation(description: "save call closure should be executed")
        
        let student = StudentUnregistered(mongoDBClient: TestMongoDBClient())
        
        student.save().response { response in
            switch response.error as! OdmError {
            case .classMetaDataNotFound:
                break
            default:
                XCTAssert(false, "Unexpected error returned")
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    // Test a root mongoDBentity Update operation
    func testRootEntityUpdate() {
        let expectation = self.expectation(description: "collection execution should be executed")
        
        let mongoDBClient = TestMongoDBClient()
        
        let student = Student(mongoDBClient: mongoDBClient)
        student.name = EntityTests.name
        student.objectId = ObjectId()
        
        mongoDBClient.database.collection.expectedMethod = .update
        mongoDBClient.database.collection.expectedInputBlock = { document in
            
            let setDocument = document["$set"] as! Document
            
            let name = setDocument[EntityTests.name] as! String
            XCTAssertEqual(name, student.name!)

            let objectId = setDocument[Utils.Consts.objectIdKey] as! ObjectId
            XCTAssertEqual(objectId, student.objectId!)
            
            expectation.fulfill()
        }
        
        student.update()
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    // Test a root mongoDB entity Update operation - Unset field
    func testRootEntityUpdateUnset() {
        let expectationResult = self.expectation(description: "update call closure should be executed")
        let expectationCollection = self.expectation(description: "collection execution should be executed")
        
        let mongoDBClient = TestMongoDBClient()
        
        let student = Student(mongoDBClient: mongoDBClient)
        student.name = EntityTests.name
        
        mongoDBClient.database.collection.expectedMethod = .insert
        
        student.save().response { response in
            
            student.name = nil
            
            mongoDBClient.database.collection.expectedMethod = .update
            mongoDBClient.database.collection.expectedInputBlock = { document in
                
                let unsetDocument = document["$unset"] as! Document
                let name = unsetDocument[EntityTests.name] as! String
                XCTAssertEqual(name, "")
                
                expectationCollection.fulfill()
            }
            
            student.update().response(completionHandler: { responseUpdate in
                XCTAssertNil(student.name)
                
                expectationResult.fulfill()
            })
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    // Test a root mongoDB entity Update operation on an entity which has not been registered (should return an error)
    func testRootEntityUpdateUnregistered() {
        let expectation = self.expectation(description: "update call closure should be executed")
        
        let student = StudentUnregistered(mongoDBClient: TestMongoDBClient())
        student.objectId = ObjectId()
        
        student.update().response { response in
            switch response.error as! OdmError {
            case .classMetaDataNotFound:
                break
            default:
                XCTAssert(false, "Unexpected error returned")
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    // Test a root mongoDBentity Update operation on an entity which has not been previously saved (would not have an ObjectId, should return an error)
    func testRootEntityUpdateUnsavedEntity() {
        let expectation = self.expectation(description: "update call closure should be executed")
        
        let student = Student(mongoDBClient: TestMongoDBClient())
        
        student.update().response { response in
            switch response.error as! OdmError {
            case .objectIdNotFound:
                break
            default:
                XCTAssert(false, "Unexpected error returned")
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    // Test a root mongoDBentity Delete operation
    func testRootEntityDelete() {
        let expectation = self.expectation(description: "collection execution should be executed")
        
        let mongoDBClient = TestMongoDBClient()
        
        let student = Student(mongoDBClient: mongoDBClient)
        student.objectId = ObjectId()
        
        mongoDBClient.database.collection.expectedMethod = .delete
        mongoDBClient.database.collection.expectedInputBlock = { document in
            
            let objectId = document[Utils.Consts.objectIdKey] as! ObjectId
            XCTAssertEqual(objectId, student.objectId!)
            
            expectation.fulfill()
        }
        
        student.delete()
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    // Test a root mongoDBentity Delete operation on an entity which has not been registered (should return an error)
    func testRootEntityDeleteUnregistered() {
        let expectation = self.expectation(description: "delete call closure should be executed")
        
        let student = StudentUnregistered(mongoDBClient: TestMongoDBClient())
        student.objectId = ObjectId()
        
        student.delete().response { response in
            switch response.error as! OdmError {
            case .classMetaDataNotFound:
                break
            default:
                XCTAssert(false, "Unexpected error returned")
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    // Test a root mongoDBentity Delete operation on an entity which has not been previously saved (would not have an ObjectId, should return an error)
    func testRootEntityDeleteUnsavedEntity() {
        let expectation = self.expectation(description: "delete call closure should be executed")
        
        let student = Student(mongoDBClient: TestMongoDBClient())
        
        student.delete().response { response in
            switch response.error as! OdmError {
            case .objectIdNotFound:
                break
            default:
                XCTAssert(false, "Unexpected error returned")
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    // MARK: - Tests Embdedded
    
    // Test a root mongoDBentity Save operation with an embedded entity
    func testRootEntitySaveEmbedded() {
        let expectationResult = self.expectation(description: "save call closure should be executed")
        let expectationCollection = self.expectation(description: "collection execution should be executed")
        
        let mongoDBClient = TestMongoDBClient()
        
        let student = Student(mongoDBClient: mongoDBClient)
       
        let reportDocument = Document(key: EntityTests.grade, value: 100)
        student.report = Report(document: reportDocument)
        
        mongoDBClient.database.collection.expectedMethod = .insert
        mongoDBClient.database.collection.expectedInputBlock = { document in
            
            let reportDocument = document[EntityTests.report] as! Document
            let grade = reportDocument[EntityTests.grade] as! Int
            XCTAssertEqual(grade, student.report!.grade!)
            
            expectationCollection.fulfill()
        }
        
        student.save().response { response in
            XCTAssertNotNil(student.objectId!)
            expectationResult.fulfill()
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    // Test a root mongoDBentity Update operation with an embedded entity
    func testRootEntityUpdateEmbedded() {
        
        let expectation = self.expectation(description: "collection execution should be executed")
        
        let mongoDBClient = TestMongoDBClient()
        
        let student = Student(mongoDBClient: mongoDBClient)
        
        let reportDocument = Document(key: EntityTests.grade, value: 100)
        student.report = Report(document: reportDocument)
        
        student.objectId = ObjectId()
        
        mongoDBClient.database.collection.expectedMethod = .update
        mongoDBClient.database.collection.expectedInputBlock = { document in
            
            let setDocument = document["$set"] as! Document
            
            let reportDocument = setDocument[EntityTests.report] as! Document
            let grade = reportDocument[EntityTests.grade] as! Int
            XCTAssertEqual(grade, student.report!.grade!)
            
            let objectId = setDocument[Utils.Consts.objectIdKey] as! ObjectId
            XCTAssertEqual(objectId, student.objectId!)
            
            expectation.fulfill()
        }
        
        student.update()
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    // Test a root mongoDBentity Update operation with an embedded entity - Unset field
    func testRootEntityUpdateEmbeddedUnset() {
        let expectationResult = self.expectation(description: "update call closure should be executed")
        let expectationCollection = self.expectation(description: "collection execution should be executed")
        
        let mongoDBClient = TestMongoDBClient()
        
        let student = Student(mongoDBClient: mongoDBClient)
        
        let reportDocument = Document(key: EntityTests.grade, value: 100)
        student.report = Report(document: reportDocument)
        
        mongoDBClient.database.collection.expectedMethod = .insert

        student.save().response { response in
            
            student.report = nil
            
            mongoDBClient.database.collection.expectedMethod = .update
            mongoDBClient.database.collection.expectedInputBlock = { document in
                
                let unsetDocument = document["$unset"] as! Document
                let report = unsetDocument[EntityTests.report] as! String
                XCTAssertEqual(report, "")
                
                expectationCollection.fulfill()
            }
            
            student.update().response { responseUpdate in
                XCTAssertNil(student.report)
                
                expectationResult.fulfill()
            }
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    // Test a root mongoDBentity Save operation with an array of embedded entities
    func testRootEntitySaveEmbeddedInArray() {
        
        let expectationResult = self.expectation(description: "save call closure should be executed")
        let expectationCollection = self.expectation(description: "collection execution should be executed")
        
        let mongoDBClient = TestMongoDBClient()
        
        let student = createStudentWithEmbeddedTeachersArray(mongoDBClient: mongoDBClient)
        
        mongoDBClient.database.collection.expectedMethod = .insert
        mongoDBClient.database.collection.expectedInputBlock = { document in
            
            let teachersArray = document[EntityTests.teachers] as! BsonArray
            
            let teacher0Doc = teachersArray[0] as! Document
            let teacher0Name = teacher0Doc[EntityTests.name] as! String
            XCTAssertEqual(teacher0Name, (student.teachers[0]).name!)
            
            let teacher1Doc = teachersArray[1] as! Document
            let teacher1Name = teacher1Doc[EntityTests.name] as! String
            XCTAssertEqual(teacher1Name, (student.teachers[1]).name!)
            
            expectationCollection.fulfill()
        }
        
        student.save().response { response in
            XCTAssertNotNil(student.objectId!)
            expectationResult.fulfill()
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    // Test an embedded mongoDBentity Update operation
    func testEmbeddedEntityUpdate() {
        
        let expectation = self.expectation(description: "collection execution should be executed")
        
        let mongoDBClient = TestMongoDBClient()
        
        let student = Student(mongoDBClient: mongoDBClient)
        
        let reportDocument = Document(key: EntityTests.grade, value: 100)
        student.report = Report(document: reportDocument)
        
        mongoDBClient.database.collection.expectedMethod = .insert
        
        student.save().response { saveResponse in
            
            let newGrade = 45
            student.report!.grade = newGrade
            
            mongoDBClient.database.collection.expectedMethod = .update
            mongoDBClient.database.collection.expectedInputBlock = { document in
                
                let setDocument = document["$set"] as! Document
                let grade = setDocument[EntityTests.report + "." + EntityTests.grade] as! Int
                XCTAssertEqual(grade, newGrade)

                expectation.fulfill()
            }
            
            student.report!.update()
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    // Test an array of embedded mongoDBentities element Update operation, when the Root entity was init from a Document
    func testEmbeddedEntityArrayElementUpdateInitFromDocument() {
        
        let expectation = self.expectation(description: "collection execution should be executed")
        
        let mongoDBClient = TestMongoDBClient()
        
        let student = createStudentWithEmbeddedTeachersArray(mongoDBClient: mongoDBClient)
        
        do {
            // Convert Student to Document, and init new Student from Document (to immitate an object recieved from the server)
            let studentDocument = try Document(extendedJson: student.toExtendedJson as! [String : Any])
            let studentFromDocument = Student(document: studentDocument, mongoDBClient: mongoDBClient)
            
            mongoDBClient.database.collection.expectedMethod = .insert

            studentFromDocument.save().response { saveResponse in
                
                let teacher0 = studentFromDocument.teachers[0]
                let newName = "name3"
                teacher0.name = newName
                
                mongoDBClient.database.collection.expectedMethod = .update
                mongoDBClient.database.collection.expectedInputBlock = { document in
                    
                    let setDocument = document["$set"] as! Document
                    let name = setDocument[EntityTests.teachers + ".$." + EntityTests.name] as! String
                    XCTAssertEqual(name, newName)
                    
                    expectation.fulfill()
                }
                
                teacher0.update()
            }
        }
        catch {
            XCTAssert(false, "Could not create document")
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    // Unfinished tests - waiting fro implementation on ODM
    
    
    // Test an array of embedded mongoDBentities element Update operation, when the properties were added after the Root object init
    func testEmbeddedEntityArrayElementUpdateAfterInit() {
        let expectation = self.expectation(description: "collection execution should be executed")
        
        let mongoDBClient = TestMongoDBClient()
        
        let student = createStudentWithEmbeddedTeachersArray(mongoDBClient: mongoDBClient)
        
        mongoDBClient.database.collection.expectedMethod = .insert
        
        student.save().response { saveResponse in
            
            let teacher0 = student.teachers[0]
            let newName = "name3"
            teacher0.name = newName
            
            mongoDBClient.database.collection.expectedMethod = .update
            mongoDBClient.database.collection.expectedInputBlock = { document in
                
                let setDocument = document["$set"] as! Document
                let name = setDocument[EntityTests.teachers + ".$." + EntityTests.name] as! String
                XCTAssertEqual(name, newName)
                
                expectation.fulfill()
            }
            
            teacher0.update().response { updateResponse in
                switch updateResponse {
                case .failure:
                    XCTAssert(false, "Update failed")
                case .success:
                    break
                }
            }
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    // Test an array of embedded mongoDBentities Update operation with element added, when the properties were added after the Root object init
    func testEmbeddedEntityArrayUpdateAddAfterInit() {
        let expectation = self.expectation(description: "collection execution should be executed")
        
        let mongoDBClient = TestMongoDBClient()
        
        let student = createStudentWithEmbeddedTeachersArray(mongoDBClient: mongoDBClient)
        
        mongoDBClient.database.collection.expectedMethod = .insert
        
        student.save().response { saveResponse in
            
            let teacher3 = Teacher(document: Document(key: EntityTests.name, value: "name3"))
            student.addToArray(path: EntityTests.teachers, item: teacher3)
            
            mongoDBClient.database.collection.expectedMethod = .update
            mongoDBClient.database.collection.expectedInputBlock = { document in
                
                let pushDocument = document["$push"] as! Document
                let techersPushedDocument = pushDocument[EntityTests.teachers] as! Document
                let teachersPushedArray = techersPushedDocument["$each"] as! BsonArray
                let pushedTeacher = teachersPushedArray[0] as! Document
                let name = pushedTeacher[EntityTests.name] as! String
                XCTAssertEqual(name, teacher3.name!)
                
                expectation.fulfill()
            }
            
            student.update().response { updateResponse in
                switch updateResponse {
                case .failure:
                    XCTAssert(false, "Update failed")
                case .success:
                    break
                }
            }
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    // Test an array of embedded mongoDBentities Update operation with element added, when the Root entity was init from a Document
    func testEmbeddedEntityArrayUpdateAddInitFromDocument() {
        let expectation = self.expectation(description: "collection execution should be executed")
        
        let mongoDBClient = TestMongoDBClient()
        
        let student = createStudentWithEmbeddedTeachersArray(mongoDBClient: mongoDBClient)
        
        do {
            // Convert Student to Document, and init new Student from Document (to immitate an object recieved from the server)
            let studentDocument = try Document(extendedJson: student.toExtendedJson as! [String : Any])
            let studentFromDocument = Student(document: studentDocument, mongoDBClient: mongoDBClient)
            
            mongoDBClient.database.collection.expectedMethod = .insert
            
            studentFromDocument.save().response { saveResponse in
                
                let teacher3 = Teacher(document: Document(key: EntityTests.name, value: "name3"))
                studentFromDocument.addToArray(path: EntityTests.teachers, item: teacher3)
                
                mongoDBClient.database.collection.expectedMethod = .update
                mongoDBClient.database.collection.expectedInputBlock = { document in
                    
                    let pushDocument = document["$push"] as! Document
                    let techersPushedDocument = pushDocument[EntityTests.teachers] as! Document
                    let teachersPushedArray = techersPushedDocument["$each"] as! BsonArray
                    let pushedTeacher = teachersPushedArray[0] as! Document
                    let name = pushedTeacher[EntityTests.name] as! String
                    XCTAssertEqual(name, teacher3.name!)
                    
                    expectation.fulfill()
                }
                
                studentFromDocument.update().response { updateResponse in
                    switch updateResponse {
                    case .failure:
                        XCTAssert(false, "Update failed")
                    case .success:
                        break
                    }
                }
            }
        }
        catch {
            XCTAssert(false, "Could not create document")
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    // Test an array of embedded mongoDBentities Update operation with element removed, when the properties were added after the Root object init
    func testEmbeddedEntityArrayUpdateRemoveAfterInit() {
        let expectation = self.expectation(description: "collection execution should be executed")
        
        let mongoDBClient = TestMongoDBClient()
        
        let student = createStudentWithEmbeddedTeachersArray(mongoDBClient: mongoDBClient)
        
        mongoDBClient.database.collection.expectedMethod = .insert
        
        student.save().response { saveResponse in
            
            let teacher0 = student.teachers[0]
            let objectId = teacher0.objectId
            student.removeFromArray(path: EntityTests.teachers, item: teacher0)
            
            mongoDBClient.database.collection.expectedMethod = .update
            mongoDBClient.database.collection.expectedInputBlock = { document in
                
                let pullDocument = document["$pull"] as? Document
                let teachersDocument = pullDocument?[EntityTests.teachers] as? Document
                let idDocument = teachersDocument![Utils.Consts.objectIdKey] as? Document
                XCTAssertEqual(idDocument!["$eq"] as! ObjectId , objectId!)
                
                expectation.fulfill()
            }
            
            student.update().response { updateResponse in
                switch updateResponse {
                case .failure:
                    XCTAssert(false, "Update failed")
                case .success:
                    break
                }
            }
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    // Test an array of embedded mongoDBentities Update operation with element removed, when the Root entity was init from a Document
    func testEmbeddedEntityArrayUpdateRemoveInitFromDocument() {
        let expectation = self.expectation(description: "collection execution should be executed")
        
        let mongoDBClient = TestMongoDBClient()
        
        let student = createStudentWithEmbeddedTeachersArray(mongoDBClient: mongoDBClient)
        
        do {
            // Convert Student to Document, and init new Student from Document (to immitate an object recieved from the server)
            let studentDocument = try Document(extendedJson: student.toExtendedJson as! [String : Any])
            let studentFromDocument = Student(document: studentDocument, mongoDBClient: mongoDBClient)
            
            mongoDBClient.database.collection.expectedMethod = .insert
            
            studentFromDocument.save().response { saveResponse in
                
                let teacher0 = studentFromDocument.teachers[0]
                let objectId = teacher0.objectId
                studentFromDocument.removeFromArray(path: EntityTests.teachers, item: teacher0)
                
                mongoDBClient.database.collection.expectedMethod = .update
                mongoDBClient.database.collection.expectedInputBlock = { document in
                    
                    let pullDocument = document["$pull"] as? Document
                    let teachersDocument = pullDocument?[EntityTests.teachers] as? Document
                    let idDocument = teachersDocument![Utils.Consts.objectIdKey] as? Document
                    XCTAssertEqual(idDocument!["$eq"] as! ObjectId , objectId!)
                    
                    expectation.fulfill()
                }
                
                studentFromDocument.update().response { updateResponse in
                    switch updateResponse {
                    case .failure:
                        XCTAssert(false, "Update failed")
                    case .success:
                        break
                    }
                }
            }
        }
        catch {
            XCTAssert(false, "Could not create document")
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    // Test an array of embedded mongoDBentities Update operation with multiple elements removed, when the properties were added after the Root object init
    func testEmbeddedEntityArrayUpdateRemoveMultipleAfterInit() {
        let expectation = self.expectation(description: "collection execution should be executed")
        
        let mongoDBClient = TestMongoDBClient()
        
        let student = createStudentWithEmbeddedTeachersArray(mongoDBClient: mongoDBClient)
        
        mongoDBClient.database.collection.expectedMethod = .insert
        
        student.save().response { saveResponse in
            
            let teacher1 = student.teachers[0]
            let objectId1 = teacher1.objectId
            student.removeFromArray(path: EntityTests.teachers, item: teacher1)
            
            let teacher2 = student.teachers[0] 
            let objectId2 = teacher2.objectId
            student.removeFromArray(path: EntityTests.teachers, item: teacher2)
            
            mongoDBClient.database.collection.expectedMethod = .update
            mongoDBClient.database.collection.expectedInputBlock = { document in
                
                let pullDocument = document["$pull"] as? Document
                let teachersDocument = pullDocument?[EntityTests.teachers] as? Document
                
                let orArray = teachersDocument?["$or"] as? BsonArray
                let firstConditionDoc = orArray?[0] as? Document
                let secondConditionDoc = orArray?[1] as? Document
                
                let firstIdDocument = firstConditionDoc![Utils.Consts.objectIdKey] as? Document
                XCTAssertEqual(firstIdDocument!["$eq"] as! ObjectId , objectId1!)
                
                let secondIdDocument = secondConditionDoc![Utils.Consts.objectIdKey] as? Document
                XCTAssertEqual(secondIdDocument!["$eq"] as! ObjectId , objectId2!)
                
                expectation.fulfill()
            }
            
            student.update().response { updateResponse in
                switch updateResponse {
                case .failure:
                    XCTAssert(false, "Update failed")
                case .success:
                    break
                }
            }
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }

    
    // Test an array of embedded mongoDBentities Update operation with elements added and removed, when the properties were added after the Root object init
   func testEmbeddedEntityArrayUpdateAddRemoveAfterInit() {
        let expectation = self.expectation(description: "collection execution should be executed")
        
        let mongoDBClient = TestMongoDBClient()
        
        let student = createStudentWithEmbeddedTeachersArray(mongoDBClient: mongoDBClient)
        
        mongoDBClient.database.collection.expectedMethod = .insert
        
        student.save().response { saveResponse in
            
            let removeTeacher = student.teachers[0]
            student.removeTeacher(removeTeacher)
            let teacher3 = Teacher(name: "name3")
            student.addTeacher(teacher3)
            
            var firstInvocation = true
            mongoDBClient.database.collection.expectedMethod = .update
            mongoDBClient.database.collection.expectedInputBlock = { document in
                if firstInvocation{
                    let pushDocument = document["$push"] as! Document
                    let techersPushedDocument = pushDocument[EntityTests.teachers] as! Document
                    let teachersPushedArray = techersPushedDocument["$each"] as! BsonArray
                    let pushedTeacher = teachersPushedArray[0] as! Document
                    let nameAdded = pushedTeacher[EntityTests.name] as! String
                    XCTAssertEqual(nameAdded, teacher3.name!)
                    firstInvocation = false
                }
                else{
                    let pullDocument = document["$pull"] as! Document
                    let teachersDocumentCriteria = pullDocument[EntityTests.teachers] as? Document
                    let conditionDoc = teachersDocumentCriteria![Utils.Consts.objectIdKey] as? Document
                    XCTAssertEqual(conditionDoc!["$eq"] as? ObjectId , removeTeacher.objectId)
                    //removeTeacher
                    expectation.fulfill()
                }
            }
            
            student.update().response { updateResponse in
                switch updateResponse {
                case .failure:
                    XCTAssert(false, "Update failed")
                case .success:
                    break
                }
            }
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
       
    // Test an array of embedded mongoDBentities Update operation with simple elements removed, when the properties were added after the Root object init
    func testEmbeddedEntityArrayUpdateRemoveSimpleAfterInit() {
        let expectation = self.expectation(description: "collection execution should be executed")
        
        let mongoDBClient = TestMongoDBClient()
        
        let student = Student(mongoDBClient: mongoDBClient)
        student.lunchBox = ["apple", "banana"]
        
        mongoDBClient.database.collection.expectedMethod = .insert
        
        student.save().response { saveResponse in
            
            student.removeLunchBox("apple")
            student.removeLunchBox("banana")
            
            mongoDBClient.database.collection.expectedMethod = .update
            mongoDBClient.database.collection.expectedInputBlock = { document in
                
                let pullDocument = document["$pull"] as? Document
                
                let inDocument = pullDocument?[EntityTests.lunchBox] as? Document
                let pullValuesBson = inDocument?["$in"] as? BsonArray
                let pullValue1 = pullValuesBson?[0] as! String
                let pullValue2 = pullValuesBson?[1] as! String
                
                XCTAssertEqual(pullValue1, "apple")
                XCTAssertEqual(pullValue2, "banana")
                
                expectation.fulfill()
            }
            
            student.update().response { updateResponse in
                switch updateResponse {
                case .failure:
                    XCTAssert(false, "Update failed")
                case .success:
                    break
                }
            }
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    


    // MARK: Helper
    
    private func createStudentWithEmbeddedTeachersArray(mongoDBClient: MongoDBClient) -> Student {
        let student = Student(mongoDBClient: mongoDBClient)
        
        let teacher1 = Teacher(document: Document(key: EntityTests.name, value: "name1"))
        let teacher2 = Teacher(document: Document(key: EntityTests.name, value: "name2"))
        
        
        student.addToArray(path: EntityTests.teachers, item: teacher1)
        student.addToArray(path: EntityTests.teachers, item: teacher2)
       
        return student
    }
    
    // MARK: - Root Entity
    
    class Student: RootEntity {
        var name: String? {
            get {
                return self[EntityTests.name] as? String
            }
            set(newName) {
                self[EntityTests.name] = newName
            }
        }
        
        var report: Report? {
            get {
                return self[EntityTests.report] as? Report
            }
            set(newReport) {
                self[EntityTests.report] = newReport
            }
        }
        
        var teachers: [Teacher] {
            get {
                do {
                   return try asArray(bsonArray: self[EntityTests.teachers] as? BsonArray)
                } catch  {
                    // failed converting
                    return []
                }
                
            }
            set(newTeachers) {
                self[EntityTests.teachers] = BsonArray(array: newTeachers)
            }
        }
        
        var lunchBox: [String] {
            get {
                do {
                    return try asArray(bsonArray: self[EntityTests.lunchBox] as? BsonArray)
                } catch  {
                    // failed converting
                    return []
                }

            }
            set(newLunchBox) {
                self[EntityTests.lunchBox] = BsonArray(array: newLunchBox)
            }
        }
        
        func addTeacher(_ teacher: Teacher){
            addToArray(path: EntityTests.teachers, item: teacher)
        }
        
        func removeTeacher(_ teacher: Teacher){
            removeFromArray(path: EntityTests.teachers, item: teacher)
        }
        
        func addLunchBox(_ lunchBox: String){
            addToArray(path: EntityTests.lunchBox, item: lunchBox)
        }
        
        func removeLunchBox(_ lunchBox: String){
            removeFromArray(path: EntityTests.lunchBox, item: lunchBox)
        }

    }
    
    class StudentMetaDataImp: EntityTypeMetaData {
        func create(document: Document) -> EmbeddedEntity? {
            return nil
        }
        
        func getEntityIdentifier() -> EntityIdentifier {
            return EntityIdentifier(Student.self)
        }
        
        func getSchema() -> [String : EntityIdentifier] {
            return [ EntityTests.name : EntityIdentifier(String.self),
                     EntityTests.report : EntityIdentifier(Report.self),
                     EntityTests.teachers : EntityIdentifier(Teacher.self),
                     EntityTests.lunchBox : EntityIdentifier(String.self)
            ]
        }
        
        var collectionName: String {
            return EntityTests.collectionName
        }
        
        var databaseName: String {
            return EntityTests.dbName
        }
    }
    
    class StudentUnregistered: RootEntity {
        var name: String? {
            get {
                return self[EntityTests.name] as? String
            }
            set(newName) {
                self[EntityTests.name] = newName
            }
        }
    }
    
    // MARK: - Embedded Entities
    
    class Report: EmbeddedEntity {
        
        var grade: Int? {
            get {
                return self[EntityTests.grade] as? Int
            }
            set(newGrade) {
                self[EntityTests.grade] = newGrade
            }
        }
    }
    
    class ReportMetaDataImp: EntityTypeMetaData {
        
        func create(document: Document) -> EmbeddedEntity? {
            let report = Report(document: document)
            return report
        }
        
        func getEntityIdentifier() -> EntityIdentifier {
            return EntityIdentifier(Report.self)
        }
        
        func getSchema() -> [String : EntityIdentifier] {
            return [EntityTests.grade : EntityIdentifier(Int.self) ]
        }
        
        var collectionName: String {
            return EntityTests.collectionName
        }
        
        var databaseName: String {
            return EntityTests.dbName
        }
    }
    
    class Teacher: EmbeddedEntity {

        convenience init(name: String){
            self.init()
            self.name = name
        }
                
        var name: String? {
            get {
                return self[EntityTests.name] as? String
            }
            set(newName) {
                self[EntityTests.name] = newName
            }
        }
    }
    
    class TeacherMetaDataImp: EntityTypeMetaData {
        
        func create(document: Document) -> EmbeddedEntity? {
            let teacher = Teacher(document: document)
            return teacher
        }
        
        func getEntityIdentifier() -> EntityIdentifier {
            return EntityIdentifier(Teacher.self)
        }
        
        func getSchema() -> [String : EntityIdentifier] {
            return [EntityTests.name : EntityIdentifier(String.self) ]
        }
        
        var collectionName: String {
            return EntityTests.collectionName
        }
        
        var databaseName: String {
            return EntityTests.dbName
        }
    }
    
    // MARK: - MongoDB Client
    
    enum ExpectedMethod {
        case update
        case insert
        case delete
    }
    
    class TestCollection: MongoDBService.Collection {
        
        var expectedMethod: ExpectedMethod?
        var expectedInputBlock: ((_ document: Document) -> ())?
        
        @discardableResult
        func find(query: Document, projection: Document?, limit: Int?) -> StitchTask<[Document]> {
            return StitchTask<[Document]>()
        }
        
        @discardableResult
        func update(query: Document, update: Document?, upsert: Bool, multi: Bool) -> StitchTask<Any> {
            let stitchTask = StitchTask<Any>()
            
            do {
                let resultDoc = try Document(extendedJson: update!.toExtendedJson as! [String : Any])
                stitchTask.result = .success(BsonArray(array: [resultDoc]))
                
                if expectedMethod == .update {
                    expectedInputBlock?(resultDoc)
                } else {
                    XCTAssert(false, "Collection executed wrong method (update)")
                }
            }
            catch {
                XCTAssert(false, "Could not create document")
            }
            
            return stitchTask
        }
        
        @discardableResult
        func insert(document: Document) ->  StitchTask<Any> {
            let stitchTask = StitchTask<Any>()
            
            var doc = document
            doc[Utils.Consts.objectIdKey] = ObjectId()
            
            do {
                let resultDoc = try Document(extendedJson: doc.toExtendedJson as! [String : Any])
                stitchTask.result = .success(BsonArray(array: [resultDoc]))
                
                if expectedMethod == .insert {
                    expectedInputBlock?(resultDoc)
                } else {
                    XCTAssert(false, "Collection executed wrong method (insert)")
                }
            }
            catch {
                XCTAssert(false, "Could not create document")
            }
            
            return stitchTask
        }
        
        @discardableResult
        func insert(documents: [Document]) ->  StitchTask<Any> {
            return StitchTask<Any>()
        }
        
        @discardableResult
        func delete(query: Document, singleDoc: Bool) -> StitchTask<Any> {
            let stitchTask = StitchTask<Any>()
            stitchTask.result = .success(BsonArray(array: [query]))
            
            if expectedMethod == .delete {
                expectedInputBlock?(query)
            } else {
                XCTAssert(false, "Collection executed wrong method (delete)")
            }
            
            return stitchTask
        }
        
        @discardableResult
        func count(query: Document) -> StitchTask<Int> {
            return StitchTask<Int>()
        }
        
        @discardableResult
        func aggregate(pipeline: [Document]) -> StitchTask<Any> {
            return StitchTask<Any>()
        }
    }
    
    class TestDatabase: Database {
        
        var client: MongoDBClient { return TestMongoDBClient() }
        var name: String { return EntityTests.dbName }
        
        let collection = TestCollection()
        
        @discardableResult
        func collection(named name: String) -> MongoDBService.Collection {
            return collection
        }
    }
    
    class TestMongoDBClient: MongoDBClient {
        
        var stitchClient: StitchClient { return TestStitchClient() }
        var serviceName: String { return EntityTests.serviceName }
        
        let database = TestDatabase()
        
        @discardableResult
        func database(named name: String) -> Database {
            return database
        }
    }
    
    class TestStitchClient: StitchClient {
        
        var auth: Auth? { return nil }
        var authUser: AuthUser? { return nil }
        var isAuthenticated: Bool { return false }
        var isAnonymous: Bool { return false }
        
        func fetchAuthProviders() -> StitchTask<AuthProviderInfo> {
            return StitchTask<AuthProviderInfo>()
        }
        
        func register(email: String, password: String) -> StitchTask<Void> {
            return StitchTask<Void>()
        }
        
        func emailConfirm(token: String, tokenId: String) -> StitchTask<Any> {
            return StitchTask<Any>()
        }
        
        func sendEmailConfirm(toEmail email: String) -> StitchTask<Void> {
            return StitchTask<Void>()
        }
        
        func resetPassword(token: String, tokenId: String) -> StitchTask<Any> {
            return StitchTask<Any>()
        }
        
        func sendResetPassword(toEmail email: String) -> StitchTask<Void> {
            return StitchTask<Void>()
        }
        
        func anonymousAuth() -> StitchTask<Bool> {
            return StitchTask<Bool>()
        }
        
        func login(withProvider provider: AuthProvider) -> StitchTask<Bool> {
            return StitchTask<Bool>()
        }
        
        func logout() -> StitchTask<Provider?> {
            return StitchTask<Provider?>()
        }
        
        func executePipeline(pipeline: Pipeline) -> StitchTask<Any> {
            return executePipeline(pipelines: [pipeline])
        }
        
        func executePipeline(pipelines: [Pipeline]) -> StitchTask<Any> {
            return StitchTask<Any>()
        }
        
    }
    
}
