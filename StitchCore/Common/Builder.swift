/**
 * A protocol defining a generic builder.
 */
public protocol Builder {
    /**
     * The type that this builder can build.
     */
    associatedtype TBuildee: Buildee

    /**
     * Initializes the builder with a closure that sets the builder's desired properties.
     */
    init(_ builder: (inout Self) -> Void)

    /**
     * Builds the `TBuildee` object.
     */
    func build() throws -> TBuildee
}

/**
 * A protocol defining a generic object that can be built by some generic `Builder`.
 */
public protocol Buildee {
    /**
     * The builder type that builds this buildee.
     */
    associatedtype TBuilder: Builder

    /**
     * Initializes this object by accepting a TBuilder and building the object.
     */
    init(_ builder: TBuilder) throws
}
