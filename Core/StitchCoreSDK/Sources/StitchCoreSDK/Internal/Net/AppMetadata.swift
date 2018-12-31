import Foundation

/// Application Metadata
public final class AppMetadata: Codable, CustomStringConvertible {
    let deploymentModel: String
    let location: String
    let hostname: String

    public var description: String {
        let encoder = JSONEncoder()

        guard let data = try? encoder.encode(self),
              let str = String(data: data, encoding: .utf8) else {
            return "<json serialization error>"
        }
        return str
    }

    enum CodingKeys: String, CodingKey {
        case deploymentModel = "deployment_model"
        case location
        case hostname
    }
}
