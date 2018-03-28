import Foundation

public protocol Transport {
    func roundTrip(request: Request) throws -> Response
}
