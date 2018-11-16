import Foundation
import MongoSwift
import XCTest
@testable import StitchCoreRemoteMongoDBService

class UpdateDescriptionUnitTests: XCMongoMobileTestCase {
    var collection: MongoCollection<Document>!

    override func setUp() {
        collection = try! XCMongoMobileTestCase.client
            .db("dublin")
            .collection("restaurants\(ObjectId().oid)")
    }

    func testUpdateDescriptionDiff() throws {
        let id = ObjectId()
        // insert our original document.
        // assert that, without comparing ids, our
        // inserted document equals our original document
        let originalJson = """
        {
        "_id": { "$oid": "\(id.oid)" },
        "shop_name": "nkd pizza",
        "address": {
        "street": "9 orwell rd",
        "city": "dublin 6",
        "county": "dublin"
        },
        "rating": 5,
        "menu": [
        "cheese",
        "pepperoni",
        "veggie"
        ],
        "employees": [
        {
        "name": "aoife",
        "age": 26,
        "euro_per_hr": 18,
        "title": "junior employee"
        },
        {
        "name": "niamh",
        "age": 27,
        "euro_per_hr": 20,
        "title": "chef"
        }
        ]
        }
        """
        var beforeDocument = try Document.init(fromJSON: originalJson)
        try collection.insertOne(beforeDocument)
        XCTAssertEqual(beforeDocument, try collection.aggregate(
            [["$project": ["employees": ["_id": 0] as Document] as Document]]
            ).next())
        var afterDocument = try Document.init(fromJSON: """
            {
            "_id": { "$oid": "\(id.oid)" },
            "shop_name": "nkd pizza",
            "address": {
            "street": "10 orwell rd",
            "city": "dublin 6",
            "county": "dublin"
            },
            "menu": [
            "cheese",
            "veggie"
            ],
            "employees": [
            {
            "name": "aoife",
            "age": 26,
            "euro_per_hr": 18,
            "title": "senior employee"
            },
            {
            "name": "niamh",
            "age": 27,
            "euro_per_hr": 20,
            "title": "chef"
            },
            {
            "name": "alice",
            "age": 29,
            "euro_per_hr": 14,
            "title": "cashier"
            }
            ]
            }
            """)
        // 1. test general nested swaps
        try testDiff(
            collection: collection,
            beforeDocument: beforeDocument,
            expectedUpdateDocument: try Document.init(fromJSON: """
            {
            "$set": {
            "address.street": "10 orwell rd",
            "menu" : ["cheese", "veggie"],
            "employees" : [
            {
            "name": "aoife",
            "age": 26,
            "euro_per_hr": 18,
            "title" : "senior employee"
            },
            {
            "name": "niamh",
            "age": 27,
            "euro_per_hr": 20,
            "title": "chef"
            },
            {
            "name": "alice",
            "age": 29,
            "euro_per_hr": 14,
            "title": "cashier"
            }
            ]
            },
            "$unset" : {
            "rating": true
            }
            }
    """), afterDocument: afterDocument)
        // 2. test array to null
        beforeDocument = afterDocument
        afterDocument = try Document.init(fromJSON: """
            {
            "_id": { "$oid": "\(id.oid)" },
            "shop_name": "nkd pizza",
            "address": {
            "street": "10 orwell rd",
            "city": "dublin 6",
            "county": "dublin"
            },
            "menu": null,
            "employees": [
            {
            "name": "aoife",
            "age": 26,
            "euro_per_hr": 18,
            "title": "senior employee"
            },
            {
            "name": "niamh",
            "age": 27,
            "euro_per_hr": 20,
            "title": "chef"
            },
            {
            "name": "alice",
            "age": 29,
            "euro_per_hr": 14,
            "title": "cashier"
            }
            ]
            }
            """)
        try testDiff(
            collection: collection,
            beforeDocument: beforeDocument,
            expectedUpdateDocument: try Document.init(fromJSON: """
    { "$set" : { "menu" : null } }
    """),
            afterDocument: afterDocument)

        // 3. test doc to empty doc
        beforeDocument = afterDocument
        afterDocument = ["_id": beforeDocument["_id"]]
        try testDiff(
            collection: collection,
            beforeDocument: beforeDocument,
            expectedUpdateDocument: try Document.init(fromJSON: """
            {
            "$unset" : {
            "shop_name" : true,
            "address" : true,
            "menu" : true,
            "employees" : true
            }
            }
    """),
            afterDocument: afterDocument)

        // 4. test empty to empty
        beforeDocument = afterDocument
        afterDocument = ["_id": id]
        try testDiff(
            collection: collection,
            beforeDocument: beforeDocument,
            expectedUpdateDocument: Document(),
            afterDocument: afterDocument
        )
    }

    func testUpdateDescriptionToUpdateDoc() {
        let updatedFields = ["hi": "there"] as Document
        let removedFields = ["meow", "bark"]

        let updateDoc = UpdateDescription(
            updatedFields: updatedFields,
            removedFields: removedFields
        ).asUpdateDocument

        XCTAssertEqual(updatedFields, updateDoc["$set"] as? Document)
        XCTAssertEqual(removedFields, (updateDoc["$unset"] as? Document)?.keys)
    }

    private func testDiff(collection: MongoCollection<Document>,
                          beforeDocument: Document,
                          expectedUpdateDocument: Document,
                          afterDocument: Document) throws {
        // create an update description via diff'ing the two documents.
        let updateDescription = beforeDocument.diff(otherDocument: afterDocument)

        XCTAssertEqual(expectedUpdateDocument,
                       updateDescription.asUpdateDocument)

        // create an update document from the update description.
        // update the original document with the update document
        try collection.updateOne(filter: ["_id": beforeDocument["_id"]],
                                 update: updateDescription.asUpdateDocument)

        // assert that our newly updated document reflects our expectations
        XCTAssertEqual(
            afterDocument,
            try collection.aggregate([["$project": ["employees": ["_id": 0] as Document] as Document]]).next())
    }
}
