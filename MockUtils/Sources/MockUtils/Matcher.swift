import Foundation

public enum Matcher<Type> {
    case any
    case with(condition: (Type) -> Bool)
}
