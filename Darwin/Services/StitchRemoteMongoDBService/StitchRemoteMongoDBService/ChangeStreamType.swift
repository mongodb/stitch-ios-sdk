// swiftlint:disable weak_delegate
import Foundation

/**
 A class representing the possible types of change streams.
*/
public class ChangeStreamType<DocumentT: Codable> {
    internal let useCompactEvents: Bool
    internal let delegate: AnyChangeStreamDelegate<DocumentT>

    private init(useCompactEvents: Bool,
                 delegate: AnyChangeStreamDelegate<DocumentT>) {
        self.useCompactEvents = useCompactEvents
        self.delegate = delegate
    }

    /**
     A change stream that produces full change events.
     See [ChangeEvent](x-source-tag://ChangeEvent)
    */
    public static func fullDocument<FullDelegateT: ChangeStreamDelegate>(
        withDelegate delegate: FullDelegateT
    ) -> ChangeStreamType<FullDelegateT.DocumentT> {
        return ChangeStreamType<FullDelegateT.DocumentT>(
            useCompactEvents: false,
            delegate: AnyChangeStreamDelegate(withDelegate: delegate))
    }

    /**
     A change stream that produces smaller, more compact change events.
     See [CompactChangeEvent](x-source-tag://CompactChangeEvent)
    */
    public static func compactDocument<CompactDelegateT: CompactChangeStreamDelegate>(
        withDelegate delegate: CompactDelegateT
    ) -> ChangeStreamType<CompactDelegateT.DocumentT> {
        return ChangeStreamType<CompactDelegateT.DocumentT>(
            useCompactEvents: true,
            delegate: AnyChangeStreamDelegate(withDelegate: delegate))
    }
}
