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
        var options: Document = [Consts.queryKey: query]
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
                guard let doc = $0 as? Document else {
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
                          upsert: Bool = false) -> StitchTask<Document> {
        return database
            .client
            .stitchClient
            .executePipeline(pipeline: createPipeline(action: Consts.updateKey,
                                                      options: [Consts.queryKey: query,
                                                                Consts.updateKey: update,
                                                                Consts.upsertKey: upsert]
        )).then {
            guard let doc = $0.asArray()[0] as? Document else {
                throw BsonError.parseValueFailure(value: $0.asArray(),
                                                  attemptedType: Document.self)
            }

            return doc
        }
    }

    @discardableResult
    public func updateMany(query: Document,
                           update: Document,
                           upsert: Bool = false) -> StitchTask<[Document]> {
        return database
            .client
            .stitchClient
            .executePipeline(pipeline: createPipeline(action: Consts.updateKey,
                                                      options: [Consts.updateKey: update,
                                                                Consts.upsertKey: upsert,
                                                                Consts.multiKey: true]))
        .then {
            return try $0.asArray().map {
                guard let doc = $0 as? Document else {
                    throw BsonError.parseValueFailure(value: $0,
                                                      attemptedType: Document.self)
                }
                return doc
            }
        }
    }

    @discardableResult
    public func insertOne(document: Document) ->  StitchTask<Document> {
        return database.client.stitchClient.executePipeline(pipelines: [
            Pipeline(action: Consts.literalKey,
                     args: [Consts.itemsKey: BSONArray(array: [document])]),
            createPipeline(action: Consts.insertKey) ]).then {
                guard let doc = $0.asArray()[0] as? Document else {
                    throw BsonError.parseValueFailure(value: $0.asArray(),
                                                      attemptedType: Document.self)
                }

                return doc
        }
    }

    @discardableResult
    public func insertMany(documents: [Document]) ->  StitchTask<[Document]> {
        return database.client.stitchClient.executePipeline(pipelines: [
            Pipeline(action: Consts.literalKey,
                     args: [Consts.itemsKey: BSONArray(array: documents)]),
            createPipeline(action: Consts.insertKey) ]).then {
                return try $0.asArray().map {
                    guard let doc = $0 as? Document else {
                        throw BsonError.parseValueFailure(value: $0,
                                                          attemptedType: Document.self)
                    }
                    return doc
                }
        }
    }

    @discardableResult
    public func deleteOne(query: Document) -> StitchTask<Int> {
        return database
            .client
            .stitchClient
            .executePipeline(pipeline: createPipeline(action: Consts.deleteKey,
                                                      options: [Consts.queryKey: query,
                                                                Consts.singleDocKey: true]))
            .then {
                guard let doc = $0.asArray()[0] as? Document,
                    let removed = doc["removed"] as? Double else {
                    throw BsonError.parseValueFailure(value: $0,
                                                      attemptedType: Document.self)
                }
                return Int(removed)
        }
    }

    @discardableResult
    public func deleteMany(query: Document) -> StitchTask<Int64> {
        return database
            .client
            .stitchClient
            .executePipeline(pipeline: createPipeline(action: Consts.deleteKey,
                                                      options: [Consts.queryKey: query,
                                                                Consts.singleDocKey: false]))
            .then {
                guard let doc = $0.asArray()[0] as? Document,
                    let removed = doc["removed"] as? Double else {
                        throw BsonError.parseValueFailure(value: $0,
                                                          attemptedType: Document.self)
                }
                return Int64(removed)
        }
    }

    @discardableResult
    public func count(query: Document) -> StitchTask<Int> {
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
    public func aggregate(pipeline: [Document]) -> StitchTask<BSONCollection> {
        return database
            .client
            .stitchClient
            .executePipeline(pipeline: createPipeline(action: Consts.aggregateKey,
                                                      options: [Consts.pipelineKey: BSONArray(array: pipeline)]))
    }
}
