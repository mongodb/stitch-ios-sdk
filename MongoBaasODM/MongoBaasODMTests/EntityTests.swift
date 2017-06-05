//
//  EntityTests.swift
//  MongoBaasODM
//
//  Created by Ofir Zucker on 28/05/2017.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import XCTest
@testable import MongoBaasODM
import MongoExtendedJson
import MongoDB
@testable import MongoCore

class EntityTests: XCTestCase {
    
    static let serviceName = "serviceName"
    static let dbName = "db"
    static let collectionName = "collection"
    
    static let name = "name"
    static let grade = "grade"
    static let report = "report"
    static let teachers = "teachers"
    
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
    
    //MARK: Tests - Root
    
    // Test a root mongo entity Save operation
    func testRootMongoEntitySave() {
        let expectationResult = self.expectation(description: "save call closure should be executed")
        let expectationCollection = self.expectation(description: "collection execution should be executed")
        
        let mongoClient = TestMongoClient()
        
        let student = Student(mongoClient: mongoClient)
        student.name = EntityTests.name
        
        mongoClient.database.collection.expectedMethod = .insert
        mongoClient.database.collection.expectedInputBlock = { document in
            
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
    
    // Test a root mongo entity Save operation on an entity which has not been registered (should return an error)
    func testRootMongoEntitySaveUnregistered() {
        let expectation = self.expectation(description: "save call closure should be executed")
        
        let student = StudentUnregistered(mongoClient: TestMongoClient())
        
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
    
    // Test a root mongo entity Update operation
    func testRootMongoEntityUpdate() {
        let expectation = self.expectation(description: "collection execution should be executed")
        
        let mongoClient = TestMongoClient()
        
        let student = Student(mongoClient: mongoClient)
        student.name = EntityTests.name
        student.objectId = ObjectId()
        
        mongoClient.database.collection.expectedMethod = .update
        mongoClient.database.collection.expectedInputBlock = { document in
            
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
    
    // Test a root mongo entity Update operation - Unset field
    func testRootMongoEntityUpdateUnset() {
        let expectationResult = self.expectation(description: "update call closure should be executed")
        let expectationCollection = self.expectation(description: "collection execution should be executed")
        
        let mongoClient = TestMongoClient()
        
        let student = Student(mongoClient: mongoClient)
        student.name = EntityTests.name
        
        mongoClient.database.collection.expectedMethod = .insert
        
        student.save().response { response in
            
            student.name = nil
            
            mongoClient.database.collection.expectedMethod = .update
            mongoClient.database.collection.expectedInputBlock = { document in
                
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
    
    // Test a root mongo entity Update operation on an entity which has not been registered (should return an error)
    func testRootMongoEntityUpdateUnregistered() {
        let expectation = self.expectation(description: "update call closure should be executed")
        
        let student = StudentUnregistered(mongoClient: TestMongoClient())
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
    
    // Test a root mongo entity Update operation on an entity which has not been previously saved (would not have an ObjectId, should return an error)
    func testRootMongoEntityUpdateUnsavedEntity() {
        let expectation = self.expectation(description: "update call closure should be executed")
        
        let student = Student(mongoClient: TestMongoClient())
        
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
    
    // Test a root mongo entity Delete operation
    func testRootMongoEntityDelete() {
        let expectation = self.expectation(description: "collection execution should be executed")
        
        let mongoClient = TestMongoClient()
        
        let student = Student(mongoClient: mongoClient)
        student.objectId = ObjectId()
        
        mongoClient.database.collection.expectedMethod = .delete
        mongoClient.database.collection.expectedInputBlock = { document in
            
            let objectId = document[Utils.Consts.objectIdKey] as! ObjectId
            XCTAssertEqual(objectId, student.objectId!)
            
            expectation.fulfill()
        }
        
        student.delete()
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    // Test a root mongo entity Delete operation on an entity which has not been registered (should return an error)
    func testRootMongoEntityDeleteUnregistered() {
        let expectation = self.expectation(description: "delete call closure should be executed")
        
        let student = StudentUnregistered(mongoClient: TestMongoClient())
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
    
    // Test a root mongo entity Delete operation on an entity which has not been previously saved (would not have an ObjectId, should return an error)
    func testRootMongoEntityDeleteUnsavedEntity() {
        let expectation = self.expectation(description: "delete call closure should be executed")
        
        let student = Student(mongoClient: TestMongoClient())
        
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
    
    //MARK: Tests - Embdedded
    
    // Test a root mongo entity Save operation with an embedded entity
    func testRootMongoEntitySaveEmbedded() {
        let expectationResult = self.expectation(description: "save call closure should be executed")
        let expectationCollection = self.expectation(description: "collection execution should be executed")
        
        let mongoClient = TestMongoClient()
        
        let student = Student(mongoClient: mongoClient)
       
        let reportDocument = Document(key: EntityTests.grade, value: 100)
        student.report = Report(document: reportDocument)
        
        mongoClient.database.collection.expectedMethod = .insert
        mongoClient.database.collection.expectedInputBlock = { document in
            
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
    
    // Test a root mongo entity Update operation with an embedded entity
    func testRootMongoEntityUpdateEmbedded() {
        
        let expectation = self.expectation(description: "collection execution should be executed")
        
        let mongoClient = TestMongoClient()
        
        let student = Student(mongoClient: mongoClient)
        
        let reportDocument = Document(key: EntityTests.grade, value: 100)
        student.report = Report(document: reportDocument)
        
        student.objectId = ObjectId()
        
        mongoClient.database.collection.expectedMethod = .update
        mongoClient.database.collection.expectedInputBlock = { document in
            
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
    
    // Test a root mongo entity Update operation with an embedded entity - Unset field
    func testRootMongoEntityUpdateEmbeddedUnset() {
        let expectationResult = self.expectation(description: "update call closure should be executed")
        let expectationCollection = self.expectation(description: "collection execution should be executed")
        
        let mongoClient = TestMongoClient()
        
        let student = Student(mongoClient: mongoClient)
        
        let reportDocument = Document(key: EntityTests.grade, value: 100)
        student.report = Report(document: reportDocument)
        
        mongoClient.database.collection.expectedMethod = .insert

        student.save().response { response in
            
            student.report = nil
            
            mongoClient.database.collection.expectedMethod = .update
            mongoClient.database.collection.expectedInputBlock = { document in
                
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
    
    // Test a root mongo entity Save operation with an array of embedded entities
    func testRootMongoEntitySaveEmbeddedInArray() {
        
        let expectationResult = self.expectation(description: "save call closure should be executed")
        let expectationCollection = self.expectation(description: "collection execution should be executed")
        
        let mongoClient = TestMongoClient()
        
        let student = Student(mongoClient: mongoClient)
        
        let teacher1 = Teacher(document: Document(key: EntityTests.name, value: "name1"))
        let teacher2 = Teacher(document: Document(key: EntityTests.name, value: "name2"))
        
        student.teachers = BsonArray(array: [teacher1, teacher2])
        
        mongoClient.database.collection.expectedMethod = .insert
        mongoClient.database.collection.expectedInputBlock = { document in
            
            let teachersArray = document[EntityTests.teachers] as! BsonArray
            
            let teacher0Doc = teachersArray[0] as! Document
            let teacher0Name = teacher0Doc[EntityTests.name] as! String
            XCTAssertEqual(teacher0Name, (student.teachers![0] as! Teacher).name!)
            
            let teacher1Doc = teachersArray[1] as! Document
            let teacher1Name = teacher1Doc[EntityTests.name] as! String
            XCTAssertEqual(teacher1Name, (student.teachers![1] as! Teacher).name!)
            
            expectationCollection.fulfill()
        }
        
        student.save().response { response in
            XCTAssertNotNil(student.objectId!)
            expectationResult.fulfill()
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    // Test an embedded mongo entity Update operation
    func testEmbeddedMongoEntityUpdate() {
        
        let expectation = self.expectation(description: "collection execution should be executed")
        
        let mongoClient = TestMongoClient()
        
        let student = Student(mongoClient: mongoClient)
        
        let reportDocument = Document(key: EntityTests.grade, value: 100)
        student.report = Report(document: reportDocument)
        
        mongoClient.database.collection.expectedMethod = .insert
        
        student.save().response { saveResponse in
            
            let newGrade = 45
            student.report!.grade = newGrade
            
            mongoClient.database.collection.expectedMethod = .update
            mongoClient.database.collection.expectedInputBlock = { document in
                
                let setDocument = document["$set"] as! Document
                let grade = setDocument[EntityTests.report + "." + EntityTests.grade] as! Int
                XCTAssertEqual(grade, newGrade)

                expectation.fulfill()
            }
            
            student.report!.update()
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    // Test an array of embedded mongo entities element Update operation, when the Root entity was init from a Document
    func testEmbeddedMongoEntityArrayElementUpdateInitFromDocument() {
        
        let expectation = self.expectation(description: "collection execution should be executed")
        
        let mongoClient = TestMongoClient()
        
        let student = Student(mongoClient: mongoClient)
        
        let teacher1 = Teacher(document: Document(key: EntityTests.name, value: "name1"))
        let teacher2 = Teacher(document: Document(key: EntityTests.name, value: "name2"))
        
        student.teachers = BsonArray(array: [teacher1, teacher2])
        
        do {
            // Convert Student to Document, and init new Student from Document (to immitate an object recieved from the server)
            let studentDocument = try Document(extendedJson: student.toExtendedJson as! [String : Any])
            let studentFromDocument = Student(document: studentDocument, mongoClient: mongoClient)
            
            mongoClient.database.collection.expectedMethod = .insert

            studentFromDocument.save().response { saveResponse in
                
                let teacher0 = studentFromDocument.teachers![0] as! Teacher
                let newName = "name3"
                teacher0.name = newName
                
                mongoClient.database.collection.expectedMethod = .update
                mongoClient.database.collection.expectedInputBlock = { document in
                    
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
    
    // Test an array of embedded mongo entities element Update operation, when the properties were added after the Root object init
    func testEmbeddedMongoEntityArrayElementUpdateAfterInit() {
        let expectation = self.expectation(description: "collection execution should be executed")
        
        let mongoClient = TestMongoClient()
        
        let student = Student(mongoClient: mongoClient)
        
        let teacher1 = Teacher(document: Document(key: EntityTests.name, value: "name1"))
        let teacher2 = Teacher(document: Document(key: EntityTests.name, value: "name2"))
        
        student.teachers = BsonArray(array: [teacher1, teacher2])
        
        mongoClient.database.collection.expectedMethod = .insert
        
        student.save().response { saveResponse in
            
            let teacher0 = student.teachers![0] as! Teacher
            let newName = "name3"
            teacher0.name = newName
            
            mongoClient.database.collection.expectedMethod = .update
            mongoClient.database.collection.expectedInputBlock = { document in
                
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

    
    //MARK: Root Entity
    
    class Student: RootMongoEntity {
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
        
        var teachers: BsonArray? {
            get {
                return self[EntityTests.teachers] as? BsonArray
            }
            set(newTeachers) {
                self[EntityTests.teachers] = newTeachers
            }
        }
    }
    
    class StudentMetaDataImp: EntityTypeMetaData {
        func create(document: Document) -> EmbeddedMongoEntity? {
            return nil
        }
        
        func getEntityIdentifier() -> EntityIdentifier {
            return EntityIdentifier(Student.self)
        }
        
        func getSchema() -> [String : EntityIdentifier] {
            return [ EntityTests.name : EntityIdentifier(String.self),
                     EntityTests.report : EntityIdentifier(Report.self),
                     EntityTests.teachers : EntityIdentifier(Teacher.self)
            ]
        }
        
        var collectionName: String {
            return EntityTests.collectionName
        }
        
        var databaseName: String {
            return EntityTests.dbName
        }
    }
    
    class StudentUnregistered: RootMongoEntity {
        var name: String? {
            get {
                return self[EntityTests.name] as? String
            }
            set(newName) {
                self[EntityTests.name] = newName
            }
        }
    }
    
    //MARK: Embedded Entities
    
    class Report: EmbeddedMongoEntity {
        
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
        
        func create(document: Document) -> EmbeddedMongoEntity? {
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
    
    class Teacher: EmbeddedMongoEntity {
        
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
        
        func create(document: Document) -> EmbeddedMongoEntity? {
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
    
    //MARK: Mongo Client
    
    enum ExpectedMethod {
        case update
        case insert
        case delete
    }
    
    class TestCollection: MongoDB.Collection {
        
        var expectedMethod: ExpectedMethod?
        var expectedInputBlock: ((_ document: Document) -> ())?
        
        @discardableResult
        func find(query: Document, projection: Document?, limit: Int?) -> BaasTask<[Document]> {
            return BaasTask<[Document]>()
        }
        
        @discardableResult
        func update(query: Document, update: Document?, upsert: Bool, multi: Bool) -> BaasTask<Any> {
            let baasTask = BaasTask<Any>()
            
            do {
                let resultDoc = try Document(extendedJson: update!.toExtendedJson as! [String : Any])
                baasTask.result = .success(BsonArray(array: [resultDoc]))
                
                if expectedMethod == .update {
                    expectedInputBlock?(resultDoc)
                } else {
                    XCTAssert(false, "Collection executed wrong method (update)")
                }
            }
            catch {
                XCTAssert(false, "Could not create document")
            }
            
            return baasTask
        }
        
        @discardableResult
        func insert(document: Document) ->  BaasTask<Any> {
            let baasTask = BaasTask<Any>()
            
            var doc = document
            doc[Utils.Consts.objectIdKey] = ObjectId()
            
            do {
                let resultDoc = try Document(extendedJson: doc.toExtendedJson as! [String : Any])
                baasTask.result = .success(BsonArray(array: [resultDoc]))
                
                if expectedMethod == .insert {
                    expectedInputBlock?(resultDoc)
                } else {
                    XCTAssert(false, "Collection executed wrong method (insert)")
                }
            }
            catch {
                XCTAssert(false, "Could not create document")
            }
            
            return baasTask
        }
        
        @discardableResult
        func insert(documents: [Document]) ->  BaasTask<Any> {
            return BaasTask<Any>()
        }
        
        @discardableResult
        func delete(query: Document, singleDoc: Bool) -> BaasTask<Any> {
            let baasTask = BaasTask<Any>()
            baasTask.result = .success(BsonArray(array: [query]))
            
            if expectedMethod == .delete {
                expectedInputBlock?(query)
            } else {
                XCTAssert(false, "Collection executed wrong method (delete)")
            }
            
            return baasTask
        }
        
        @discardableResult
        func count(query: Document) -> BaasTask<Int> {
            return BaasTask<Int>()
        }
        
        @discardableResult
        func aggregate(pipeline: [Document]) -> BaasTask<Any> {
            return BaasTask<Any>()
        }
    }
    
    class TestDatabase: Database {
        
        var client: MongoClient { return TestMongoClient() }
        var name: String { return EntityTests.dbName }
        
        let collection = TestCollection()
        
        @discardableResult
        func collection(named name: String) -> MongoDB.Collection {
            return collection
        }
    }
    
    class TestMongoClient: MongoClient {
        
        var baasClient: BaasClient { return TestBaasClient() }
        var serviceName: String { return EntityTests.serviceName }
        
        let database = TestDatabase()
        
        @discardableResult
        func database(named name: String) -> Database {
            return database
        }
    }
    
    class TestBaasClient: BaasClient {
        
        var auth: Auth? { return nil }
        var authUser: AuthUser? { return nil }
        var isAuthenticated: Bool { return false }
        var isAnonymous: Bool { return false }
        
        func fetchAuthProviders() -> BaasTask<AuthProviderInfo> {
            return BaasTask<AuthProviderInfo>()
        }
        
        func register(email: String, password: String) -> BaasTask<Void> {
            return BaasTask<Void>()
        }
        
        func emailConfirm(token: String, tokenId: String) -> BaasTask<Any> {
            return BaasTask<Any>()
        }
        
        func sendEmailConfirm(toEmail email: String) -> BaasTask<Void> {
            return BaasTask<Void>()
        }
        
        func resetPassword(token: String, tokenId: String) -> BaasTask<Any> {
            return BaasTask<Any>()
        }
        
        func sendResetPassword(toEmail email: String) -> BaasTask<Void> {
            return BaasTask<Void>()
        }
        
        func anonymousAuth() -> BaasTask<Bool> {
            return BaasTask<Bool>()
        }
        
        func login(withProvider provider: AuthProvider) -> BaasTask<Bool> {
            return BaasTask<Bool>()
        }
        
        func logout() -> BaasTask<Provider?> {
            return BaasTask<Provider?>()
        }
        
        func executePipeline(pipeline: Pipeline) -> BaasTask<Any> {
            return executePipeline(pipelines: [pipeline])
        }
        
        func executePipeline(pipelines: [Pipeline]) -> BaasTask<Any> {
            return BaasTask<Any>()
        }
        
    }
    
}
