import ComposableArchitecture
import GRDB

private enum GRDBDefaultDatabaseQueueKey: TestDependencyKey {
  static var testValue: DatabaseQueue {
    try! DatabaseQueue()
  }
}

extension DependencyValues {
  public var defaultDatabaseQueue: DatabaseQueue {
    get { self[GRDBDefaultDatabaseQueueKey.self] }
    set { self[GRDBDefaultDatabaseQueueKey.self] = newValue }
  }
}

public protocol GRDBQuery: Hashable {
  associatedtype Value
  func fetch(_ db: Database) throws -> Value
}

extension PersistenceKey {
  public static func query<Query: GRDBQuery>(_ query: Query) -> Self
  where Self == GRDBQueryKey<Query> {
    Self(query)
  }
}

public final class GRDBQueryKey<Query: GRDBQuery>: PersistenceKey {
  let query: Query

  public init(_ query: Query) {
    self.query = query
  }

  public static func == (lhs: GRDBQueryKey, rhs: GRDBQueryKey) -> Bool {
    lhs.query == rhs.query
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(query)
  }

  public func load() -> Query.Value? {
    @Dependency(\.defaultDatabaseQueue) var defaultDatabaseQueue
    return try? defaultDatabaseQueue.read(query.fetch(_:))
  }

  public func save(_ value: Query.Value) {
  }

  public func subscribe(
    didSet: @escaping (Query.Value?) -> Void
  ) -> Shared<Query.Value>.Subscription {
    @Dependency(\.defaultDatabaseQueue) var defaultDatabaseQueue
    let observation = ValueObservation.tracking(query.fetch(_:))
    let cancellable = observation.start(in: defaultDatabaseQueue) { error in

    } onChange: { newValue in
      didSet(newValue)
    }
    return Shared.Subscription {
      cancellable.cancel()
    }
  }
}

extension FetchRequest where RowDecoder: FetchableRecord & Identifiable {
    /// For example:
    ///
    /// ```
    /// let players = try Player.all().fetchIdentifiedArray(db)
    /// ```
    public func fetchIdentifiedArray(_ db: Database) throws -> IdentifiedArrayOf<RowDecoder> {
        try IdentifiedArray(fetchCursor(db))
    }
}
