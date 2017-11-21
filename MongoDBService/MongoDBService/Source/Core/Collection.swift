//
//  Collection.swift
//  MongoDBService
//

import Foundation

import StitchCore
import ExtendedJson

public struct UpdateResult: Codable {
    public let matchedCount: Int32
}

public struct DeleteResult: Codable {
    public let deletedCount: Int32
}

public struct InsertOneResult: Codable {
    public let insertedId: ObjectId
}

public struct InsertManyResult: Codable {
    public let insertedIds: [ObjectId]
}

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

    // MARK: - Private
    private func createPipeline(action: String, options: Document? = nil) -> Pipeline {
        var args = options ?? [:]
        args[Consts.databaseKey] = database.name
        args[Consts.collectionKey] = name
        return Pipeline(action: action,
                        service: database.client.serviceName,
                        args: args)
    }

    // MARK: - Public
    @discardableResult
    public func find(query: Document,
                     projection: Document? = nil,
                     limit: Int? = nil) -> StitchTask<[Document]> {
        var options: Document = [
            Consts.queryKey: query,
            Consts.databaseKey: database.name,
            Consts.collectionKey: self.name
        ]
        if let projection = projection {
            options[Consts.projectionKey] = projection
        }

        if let limit = limit {
            options[Consts.limitKey] = limit
        }

        return database.client.stitchClient.executeServiceFunction(name: "find",
                                                                     service: database.client.serviceName,
                                                                     args: options)
        .then {
            guard let array = $0 as? [Any] else {
                throw StitchError.responseParsingFailed(reason: "\($0) was not array")
            }

            return try array.map {
                guard let doc = try Document.fromExtendedJson(xjson: $0) as? Document else {
                    throw BsonError.parseValueFailure(value: $0,
                                                      attemptedType: Document.self)
                }
                return doc
            }
        }
    }

    @discardableResult
    public func updateOne(query: Document,
                          update: Document,
                          upsert: Bool = false) -> StitchTask<UpdateResult> {
        return database.client.stitchClient.executeServiceFunction(name: "updateOne",
                                                                    service: database.client.serviceName,
                                                                    args: [Consts.queryKey: query,
                                                                           Consts.updateKey: update,
                                                                           Consts.upsertKey: upsert,
                                                                           Consts.databaseKey: database.name,
                                                                           Consts.collectionKey: self.name] as Document)
        .then {
            guard let doc = try Document.fromExtendedJson(xjson: $0) as? Document else {
                throw BsonError.parseValueFailure(value: $0,
                                                  attemptedType: Document.self)
            }
            return try BSONDecoder().decode(UpdateResult.self, from: doc)
        }
    }

    @discardableResult
    public func updateMany(query: Document,
                           update: Document,
                           upsert: Bool = false) -> StitchTask<UpdateResult> {
        return database.client.stitchClient.executeServiceFunction(name: "updateMany",
                                                                    service: database.client.serviceName,
                                                                    args: [Consts.updateKey: update,
                                                                           Consts.upsertKey: upsert,
                                                                           Consts.multiKey: true,
                                                                           Consts.databaseKey: database.name,
                                                                           Consts.collectionKey: self.name] as Document)
        .then {
            guard let doc = try Document.fromExtendedJson(xjson: $0) as? Document else {
                throw BsonError.parseValueFailure(value: $0,
                                                  attemptedType: Document.self)
            }
            return try BSONDecoder().decode(UpdateResult.self, from: doc)
        }
    }

    @discardableResult
    public func insertOne(document: Document) ->  StitchTask<InsertOneResult> {
        return database.client.stitchClient.executeServiceFunction(name: "insertOne",
                                                                    service: database.client.serviceName,
                                                                    args: ["document": document,
                                                                           Consts.databaseKey: database.name,
                                                                           Consts.collectionKey: self.name] as Document)
        .then {
            guard let doc = try Document.fromExtendedJson(xjson: $0) as? Document else {
                throw BsonError.parseValueFailure(value: $0,
                                                  attemptedType: Document.self)
            }

            return try BSONDecoder().decode(InsertOneResult.self, from: doc)
        }
    }

    @discardableResult
    public func insertMany(documents: [Document]) ->  StitchTask<InsertManyResult> {
        return database.client.stitchClient.executeServiceFunction(name: "insertMany",
                                                                   service: database.client.serviceName,
                                                                   args: ["documents": BSONArray(array: documents),
                                                                          Consts.databaseKey: database.name,
                                                                          Consts.collectionKey: self.name] as Document)
            .then {
                guard let doc = try Document.fromExtendedJson(xjson: $0) as? Document else {
                    throw BsonError.parseValueFailure(value: $0,
                                                      attemptedType: Document.self)
                }

                return try BSONDecoder().decode(InsertManyResult.self, from: doc)
        }
    }

    @discardableResult
    public func deleteOne(query: Document) -> StitchTask<DeleteResult> {
        return database.client.stitchClient.executeServiceFunction(name: "deleteOne",
                                                                   service: database.client.serviceName,
                                                                   args: [Consts.queryKey: query,
                                                                          Consts.singleDocKey: true,
                                                                          Consts.databaseKey: database.name,
                                                                          Consts.collectionKey: self.name] as Document)
            .then {
                guard let doc = try Document.fromExtendedJson(xjson: $0) as? Document else {
                    throw BsonError.parseValueFailure(value: $0,
                                                      attemptedType: Document.self)
                }

                return try BSONDecoder().decode(DeleteResult.self, from: doc)
        }
    }

    @discardableResult
    public func deleteMany(query: Document) -> StitchTask<DeleteResult> {
        return database.client.stitchClient.executeServiceFunction(name: "deleteMany",
                                                                    service: database.client.serviceName,
                                                                    args: [Consts.queryKey: query,
                                                                           Consts.singleDocKey: false,
                                                                           Consts.databaseKey: database.name,
                                                                           Consts.collectionKey: self.name] as Document)
            .then {
                guard let doc = try Document.fromExtendedJson(xjson: $0) as? Document else {
                    throw BsonError.parseValueFailure(value: $0,
                                                      attemptedType: Document.self)
                }

                return try BSONDecoder().decode(DeleteResult.self, from: doc)
        }
    }

    @discardableResult
    public func count(query: Document) -> StitchTask<Int> {
        return database.client.stitchClient.executeServiceFunction(name: "find",
                                                                   service: database.client.serviceName,
                                                                   args: [Consts.queryKey: query,
                                                                          Consts.countKey: true,
                                                                          Consts.databaseKey: database.name,
                                                                          Consts.collectionKey: self.name] as Document)
        .then {
            guard let count = try Int.fromExtendedJson(xjson: $0) as? Int else {
                throw BsonError.parseValueFailure(value: $0,
                                                  attemptedType: Int.self)
            }

            return count
        }
    }

    @discardableResult
    public func aggregate(pipeline: [Document]) -> StitchTask<BSONArray> {
        return database.client.stitchClient.executeServiceFunction(name: "aggregate",
                                                                    service: database.client.serviceName,
                                                                    args: [Consts.pipelineKey: BSONArray(array: pipeline),
                                                                           Consts.databaseKey: database.name,
                                                                           Consts.collectionKey: self.name] as Document)
        .then {
            guard let bson = try BSONArray.fromExtendedJson(xjson: $0) as? BSONArray else {
                throw BsonError.parseValueFailure(value: $0,
                                                  attemptedType: BSONArray.self)
            }

            return bson
        }
    }
}
