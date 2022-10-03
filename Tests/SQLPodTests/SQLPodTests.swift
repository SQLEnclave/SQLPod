import XCTest
@testable import SQLPod
import TiqDB
import Jack

open class SQLPod : JackPod {
    public var metadata: JackPodMetaData {
        JackPodMetaData(homePage: URL(string: "https://github.com/jectivex/SQLPod")!)
    }

    public init() {
    }

    @Stack(mutable: false) public private(set) var version = SQLPodVersionNumber
    @Stack(mutable: false) public private(set) var tiqdbVersion = TiqDBVersionNumber
    //@Stack(mutable: false) public private(set) var sqliteVersion = sqlite3_version

    @Jack("db") var _db = db
    open func db(path: String? = nil, config: Config? = nil) throws -> SQLDBWriter {
        // translate our codable config param into the equivalent calls on TiqDB.Configuration
        var cfg = Configuration()
        if let config = config {
            if let readonly = config.readonly {
                cfg.readonly = readonly
            }
            if let passphrase = config.passphrase {
                cfg.prepareDatabase { db in
                    try db.usePassphrase(passphrase)
                }
            }
            if let foreignKeysEnabled = config.foreignKeysEnabled {
                cfg.foreignKeysEnabled = foreignKeysEnabled
            }
            if let label = config.label {
                cfg.label = label
            }
            if let acceptsDoubleQuotedStringLiterals = config.acceptsDoubleQuotedStringLiterals {
                cfg.acceptsDoubleQuotedStringLiterals = acceptsDoubleQuotedStringLiterals
            }
            if let observesSuspensionNotifications = config.observesSuspensionNotifications {
                cfg.observesSuspensionNotifications = observesSuspensionNotifications
            }
            if let allowsUnsafeTransactions = config.allowsUnsafeTransactions {
                cfg.allowsUnsafeTransactions = allowsUnsafeTransactions
            }
            if let maximumReaderCount = config.maximumReaderCount {
                cfg.maximumReaderCount = maximumReaderCount
            }
        }

        guard let path = path else { // if no path then use in-memory database
            return SQLDBWriter(dbq: DatabaseQueue(configuration: cfg))
        }
        if config?.pool == true {
            return SQLDBWriter(dbq: try DatabasePool(path: path, configuration: cfg))
        } else {
            return SQLDBWriter(dbq: try DatabaseQueue(path: path, configuration: cfg))
        }
    }

    /// Codable peer to ``TiqDB.Configuration``
    public struct Config : Codable, JXConvertible {
        public var pool: Bool?
        public var readonly: Bool?
        public var passphrase: String?
        public var foreignKeysEnabled: Bool?
        public var label: String?
        public var acceptsDoubleQuotedStringLiterals: Bool?
        public var observesSuspensionNotifications: Bool?
        //public var defaultTransactionKind: Database.TransactionKind?
        public var allowsUnsafeTransactions: Bool?
        //public var busyMode: Database.BusyMode = .immediateError
        //var readonlyBusyMode: Database.BusyMode? = nil
        public var maximumReaderCount: Int?
        //public var qos: DispatchQoS = .default
        //public var targetQueue: DispatchQueue? = nil
    }
}

open class SQLDBWriter : JackedReference {
    let dbq: DatabaseWriter

    public init(dbq: DatabaseWriter) {
        self.dbq = dbq
    }

    @Jack("query") var _query = query
    open func query(sql: String, args: [JXValue]?) throws {
        try dbq.read { db in
            try db.execute(sql: sql, arguments: extractStatementArguments(from: args ?? []))
        }
    }

    #warning("TODO")
    private func extractStatementArguments(from values: [JXValue]) throws -> StatementArguments {
        return .init()
    }
}

final class SQLPodTests: XCTestCase {
    func testSQLPodVersion() {
        XCTAssertLessThanOrEqual(0_000_001, SQLPodVersionNumber)
    }
    
    func testSQLPod() throws {
        let dbpath = "/tmp/\(UUID().uuidString).sqlite"

//        let db = try SQLPod().db()
//        db.query(sql: "select 1")

        var config = Configuration()
        config.readonly = false
        config.prepareDatabase { db in
            try db.usePassphrase("secret")
        }
        let dbq = try DatabaseQueue(path: dbpath, configuration: config)

        try dbq.write { db in
            try db.execute(sql: """
                CREATE TABLE place (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  title TEXT NOT NULL,
                  favorite BOOLEAN NOT NULL DEFAULT 0,
                  latitude DOUBLE NOT NULL,
                  longitude DOUBLE NOT NULL)
                """)

            try db.execute(sql: """
                INSERT INTO place (title, favorite, latitude, longitude)
                VALUES (?, ?, ?, ?)
                """, arguments: ["Paris", true, 48.85341, 2.3488])

            let parisId = db.lastInsertedRowID

            // Avoid SQL injection with SQL interpolation
            try db.execute(literal: """
                INSERT INTO place (title, favorite, latitude, longitude)
                VALUES (\("King's Cross"), \(true), \(51.52151), \(-0.12763))
                """)

            print("created: \(parisId)")
        }
    }

    func testJackDatabase() throws {
        class SQLPodDebug : SQLPod {
            static var SQLPodDebugCount = 0
            override init() {
                Self.SQLPodDebugCount += 1
            }
            deinit {
                Self.SQLPodDebugCount -= 1
            }
        }

        do {
            let pod = SQLPodDebug()
            let ctx = try JXContext().jack(pods: [ "sql": pod ])

            XCTAssertLessThanOrEqual(0_000_001, try ctx.eval("sql.version").numberValue)
            XCTAssertLessThanOrEqual(8_000_000, try ctx.eval("sql.tiqdbVersion").numberValue)

            XCTAssertTrue(try ctx.eval("sql").isObject)
            XCTAssertTrue(try ctx.eval("sql.db").isFunction)

            try ctx.eval("sql.db().query('select 1', null)")
            //try ctx.eval("db.query('select 1')")

            XCTAssertEqual(1, SQLPodDebug.SQLPodDebugCount)
        }
        XCTAssertEqual(0, SQLPodDebug.SQLPodDebugCount)
    }
}

extension JXContext {
    /// Set up a context with the given keys JackPods.
    /// - Parameter pods: the dictionary of pods to jack into the context
    /// - Returns: the context itself
    @discardableResult public func jack(pods: KeyValuePairs<String, any JackPod>) throws -> Self {
        for (key, value) in pods {
            try value.jack(into: self.global.setProperty(key, self.object()))
        }
        return self
    }
}

