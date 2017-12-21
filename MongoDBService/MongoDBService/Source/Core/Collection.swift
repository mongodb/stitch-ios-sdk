//
//  Collection.swift
//  MongoDBService
//

import Foundation

import StitchCore
import ExtendedJson
import PromiseKit

public struct Collection {
    private struct Consts {
        static let databaseKey =        "database"
        static let collectionKey =      "collection"
        static let queryKey =           "query"
        static let projectionKey =      "projection"
        static let countKey =           "count"
        static let limitKey =           "limit"
        static let updateKey =          "update"
        static let upsertKey =          "upsert"
        static let multiKey =           "multi"
        static let literalKey =         "literal"
        static let insertKey =          "insert"
        static let itemsKey =           "items"
        static let deleteKey =          "delete"
        static let singleDocKey =       "singleDoc"
        static let aggregateKey =       "aggregate"
        static let pipelineKey =        "pipeline"
    }

    private let database: Database
    private let name: String

    internal init(database: Database, name: String) {
        self.database = database
        self.name = name
    }

    // MARK: - Public
    @discardableResult
    public func find(query: Document,
                     projection: Document? = nil,
                     limit: Int) -> Promise<[Document]> {
        var options: Document = [
            Consts.queryKey: query,
            Consts.databaseKey: database.name,
            Consts.collectionKey: self.name,
            Consts.limitKey: limit
        ]
        if let projection = projection {
            options[Consts.projectionKey] = projection
        }

        return database.client.stitchClient.executeServiceFunction(name: "find",
                                                                     service: database.client.serviceName,
                                                                     args: options)
        .then { (any: Any) -> [Document] in
            guard let array = any as? [Any] else {
                throw StitchError.responseParsingFailed(reason: "\(any) was not array")
            }

            return try array.map { (any: Any) -> Document in
                guard let doc = try Document.fromExtendedJson(xjson: any) as? Document else {
                    throw BsonError.parseValueFailure(value: any,
                                                      attemptedType: Document.self)
                }
                return doc
            }
        }
    }

    @discardableResult
    public func updateOne(query: Document,
                          update: Document,
                          upsert: Bool = false) -> Promise<Document> {
        return database.client.stitchClient.executeServiceFunction(name: "updateOne",
                                                                    service: database.client.serviceName,
                                                                    args: [Consts.queryKey: query,
                                                                           Consts.updateKey: update,
                                                                           Consts.upsertKey: upsert,
                                                                           Consts.databaseKey: database.name,
                                                                           Consts.collectionKey: self.name] as Document)
        .then { (any: Any) -> Document in
            guard let doc = try Document.fromExtendedJson(xjson: any) as? Document else {
                throw BsonError.parseValueFailure(value: any,
                                                   attemptedType: Document.self)
            }

            return doc
        }
    }

    @discardableResult
    public func updateMany(query: Document,
                           update: Document,
                           upsert: Bool = false) -> Promise<Document> {
        return database.client.stitchClient.executeServiceFunction(name: "updateMany",
                                                                    service: database.client.serviceName,
                                                                    args: [Consts.updateKey: update,
                                                                           Consts.upsertKey: upsert,
                                                                           Consts.multiKey: true,
                                                                           Consts.databaseKey: database.name,
                                                                           Consts.collectionKey: self.name] as Document)
        .then { (any: Any) -> Document in
            guard let doc = try Document.fromExtendedJson(xjson: any) as? Document else {
                throw BsonError.parseValueFailure(value: any,
                                                  attemptedType: Document.self)
            }

            return doc
        }
    }

    @discardableResult
    public func insertOne(document: Document) ->  Promise<ObjectId> {
        return database.client.stitchClient.executeServiceFunction(name: "insertOne",
                                                                    service: database.client.serviceName,
                                                                    args: ["document": document,
                                                                           Consts.databaseKey: database.name,
                                                                           Consts.collectionKey: self.name] as Document)
        .then { (any: Any) -> ObjectId in
            guard let doc = try Document.fromExtendedJson(xjson: any) as? Document,
                let insertedId = doc["insertedId"] as? ObjectId else {
                throw BsonError.parseValueFailure(value: any,
                                                  attemptedType: Document.self)
            }

            return insertedId
        }
    }

    @discardableResult
    public func insertMany(documents: [Document]) ->  Promise<[ObjectId]> {
        return database.client.stitchClient.executeServiceFunction(name: "insertMany",
                                                                   service: database.client.serviceName,
                                                                   args: ["documents": BSONArray(array: documents),
                                                                          Consts.databaseKey: database.name,
                                                                          Consts.collectionKey: self.name] as Document)
            .then { (any: Any) -> [ObjectId] in
                guard let doc = try Document.fromExtendedJson(xjson: any) as? Document,
                    let insertedIds = doc["insertedIds"] as? BSONArray else {
                        throw BsonError.parseValueFailure(value: any,
                                                          attemptedType: Document.self)
                }

                return try insertedIds.map { (any: Any) -> ObjectId in
                    guard let oid = any as? ObjectId else {
                        throw BsonError.parseValueFailure(value: any,
                                                          attemptedType: ObjectId.self)
                    }
                    return oid
                }
        }
    }

    @discardableResult
    public func deleteOne(query: Document) -> Promise<Document> {
        return database.client.stitchClient.executeServiceFunction(name: "deleteOne",
                                                                   service: database.client.serviceName,
                                                                   args: [Consts.queryKey: query,
                                                                          Consts.singleDocKey: true,
                                                                          Consts.databaseKey: database.name,
                                                                          Consts.collectionKey: self.name] as Document)
            .then { (any: Any) -> Document in
                guard let doc = try Document.fromExtendedJson(xjson: any) as? Document else {
                    throw BsonError.parseValueFailure(value: any,
                                                      attemptedType: Document.self)
                }

                return doc
        }
    }

    @discardableResult
    public func deleteMany(query: Document) -> Promise<Document> {
        return database.client.stitchClient.executeServiceFunction(name: "deleteMany",
                                                                    service: database.client.serviceName,
                                                                    args: [Consts.queryKey: query,
                                                                           Consts.singleDocKey: false,
                                                                           Consts.databaseKey: database.name,
                                                                           Consts.collectionKey: self.name] as Document)
            .then { (any: Any) -> Document in
                guard let doc = try Document.fromExtendedJson(xjson: any) as? Document else {
                    throw BsonError.parseValueFailure(value: any,
                                                      attemptedType: Document.self)
                }

                return doc
        }
    }

    @discardableResult
    public func count(query: Document, projection: Document? = nil) -> Promise<Int> {
        var opts: Document = [Consts.queryKey: query,
                              Consts.countKey: true,
                              Consts.databaseKey: database.name,
                              Consts.collectionKey: self.name]

        if (projection != nil) {
            opts[Consts.projectionKey] = projection
        }

        return database.client.stitchClient.executeServiceFunction(name: "count",
                                                                   service: database.client.serviceName,
                                                                   args: opts)
        .then { (any: Any) -> Int in
            guard let count = try Int.fromExtendedJson(xjson: any) as? Int else {
                throw BsonError.parseValueFailure(value: any,
                                                  attemptedType: Int.self)
            }

            return count
        }
    }

    @discardableResult
    public func aggregate(docs: [Document]) -> Promise<BSONArray> {
        return database.client.stitchClient.executeServiceFunction(name: "aggregate",
                                                                    service: database.client.serviceName,
                                                                    args: [Consts.pipelineKey: BSONArray(array: docs),
                                                                           Consts.databaseKey: database.name,
                                                                           Consts.collectionKey: self.name] as Document)
        .then { (any: Any) -> BSONArray in
            guard let bson = try BSONArray.fromExtendedJson(xjson: any) as? BSONArray else {
                throw BsonError.parseValueFailure(value: any,
                                                  attemptedType: BSONArray.self)
            }

            return bson
        }
    }
}
