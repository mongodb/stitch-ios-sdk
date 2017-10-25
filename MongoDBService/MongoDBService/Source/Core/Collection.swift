//
//  Collection.swift
//  MongoDBService
//

import Foundation

import StitchCore
import ExtendedJson

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
    private func createPipeline(action: String, options: BsonDocument? = nil) -> Pipeline {
        var args = options ?? [:]
        args[Consts.databaseKey] = database.name
        args[Consts.collectionKey] = name
        return Pipeline(action: action,
                        service: database.client.serviceName,
                        args: args)
    }

    // MARK: - Public
    @discardableResult
    public func find(query: BsonDocument,
                     projection: BsonDocument? = nil,
                     limit: Int? = nil) -> StitchTask<[BsonDocument]> {
        var options: BsonDocument = [Consts.queryKey: query]
        if let projection = projection {
            options[Consts.projectionKey] = projection
        }

        if let limit = limit {
            options[Consts.limitKey] = limit
        }

        return database.client.stitchClient.executePipeline(pipeline: createPipeline(action: "find",
                                                                                     options: options))
        .then {
            return try $0.asArray().map {
                guard let doc = $0 as? BsonDocument else {
                    throw BsonError.parseValueFailure(value: $0,
                                                      attemptedType: BsonDocument.self)
                }
                return doc
            }
        }
    }

    @discardableResult
    public func updateOne(query: BsonDocument,
                          update: BsonDocument,
                          upsert: Bool = false) -> StitchTask<BsonDocument> {
        return database
            .client
            .stitchClient
            .executePipeline(pipeline: createPipeline(action: Consts.updateKey,
                                                      options: [Consts.queryKey: query,
                                                                Consts.updateKey: update,
                                                                Consts.upsertKey: upsert]
        )).then {
            guard let doc = $0.asArray()[0] as? BsonDocument else {
                throw BsonError.parseValueFailure(value: $0.asArray(),
                                                  attemptedType: BsonDocument.self)
            }

            return doc
        }
    }

    @discardableResult
    public func updateMany(query: BsonDocument,
                           update: BsonDocument,
                           upsert: Bool = false) -> StitchTask<[BsonDocument]> {
        return database
            .client
            .stitchClient
            .executePipeline(pipeline: createPipeline(action: Consts.updateKey,
                                                      options: [Consts.updateKey: update,
                                                                Consts.upsertKey: upsert,
                                                                Consts.multiKey: true]))
        .then {
            return try $0.asArray().map {
                guard let doc = $0 as? BsonDocument else {
                    throw BsonError.parseValueFailure(value: $0,
                                                      attemptedType: BsonDocument.self)
                }
                return doc
            }
        }
    }

    @discardableResult
    public func insertOne(document: BsonDocument) ->  StitchTask<BsonDocument> {
        return database.client.stitchClient.executePipeline(pipelines: [
            Pipeline(action: Consts.literalKey,
                     args: [Consts.itemsKey: BsonArray(array: [document])]),
            createPipeline(action: Consts.insertKey) ]).then {
                guard let doc = $0.asArray()[0] as? BsonDocument else {
                    throw BsonError.parseValueFailure(value: $0.asArray(),
                                                      attemptedType: BsonDocument.self)
                }

                return doc
        }
    }

    @discardableResult
    public func insertMany(documents: [BsonDocument]) ->  StitchTask<[BsonDocument]> {
        return database.client.stitchClient.executePipeline(pipelines: [
            Pipeline(action: Consts.literalKey,
                     args: [Consts.itemsKey: BsonArray(array: documents)]),
            createPipeline(action: Consts.insertKey) ]).then {
                return try $0.asArray().map {
                    guard let doc = $0 as? BsonDocument else {
                        throw BsonError.parseValueFailure(value: $0,
                                                          attemptedType: BsonDocument.self)
                    }
                    return doc
                }
        }
    }

    @discardableResult
    public func deleteOne(query: BsonDocument) -> StitchTask<Int> {
        return database
            .client
            .stitchClient
            .executePipeline(pipeline: createPipeline(action: Consts.deleteKey,
                                                      options: [Consts.queryKey: query,
                                                                Consts.singleDocKey: true]))
            .then {
                guard let doc = $0.asArray()[0] as? BsonDocument,
                    let removed = doc["removed"] as? Double else {
                    throw BsonError.parseValueFailure(value: $0,
                                                      attemptedType: BsonDocument.self)
                }
                return Int(removed)
        }
    }

    @discardableResult
    public func deleteMany(query: BsonDocument) -> StitchTask<Int64> {
        return database
            .client
            .stitchClient
            .executePipeline(pipeline: createPipeline(action: Consts.deleteKey,
                                                      options: [Consts.queryKey: query,
                                                                Consts.singleDocKey: false]))
            .then {
                guard let doc = $0.asArray()[0] as? BsonDocument,
                    let removed = doc["removed"] as? Double else {
                        throw BsonError.parseValueFailure(value: $0,
                                                          attemptedType: BsonDocument.self)
                }
                return Int64(removed)
        }
    }

    @discardableResult
    public func count(query: BsonDocument) -> StitchTask<Int> {
        return database
            .client
            .stitchClient
            .executePipeline(pipeline: createPipeline(action: "find",
                                                      options: [Consts.queryKey: query,
                                                                Consts.countKey: true])).then { result in
            guard let int = result.asArray().first as? Int32 else {
                    throw StitchError.responseParsingFailed(reason: "failed converting result to documents array.")
            }

            return Int(int)
        }
    }

    @discardableResult
    public func aggregate(pipeline: [BsonDocument]) -> StitchTask<BsonCollection> {
        return database
            .client
            .stitchClient
            .executePipeline(pipeline: createPipeline(action: Consts.aggregateKey,
                                                      options: [Consts.pipelineKey: BsonArray(array: pipeline)]))
    }
}
