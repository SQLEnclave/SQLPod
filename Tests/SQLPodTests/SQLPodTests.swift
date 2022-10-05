import XCTest
import SQLPod
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

    @Jack("execute") var _execute = execute
    open func execute(sql: String, arg: JXValue?) throws {
        try dbq.read { db in
            try db.execute(sql: sql, arguments: extractStatementArguments(from: arg))
        }
    }

    @Jack("query") var _query = query
    open func query(sql: String, arg: JXValue?) throws -> [JXValue] {
        return try dbq.read { db in
            var values: [JXValue] = []
            for row in try Row.fetchAll(db, sql: sql, arguments: extractStatementArguments(from: arg)) {
                if let ctx = JXContext.currentContext {
                    let obj = ctx.object()
                    for key in row.columnNames {
                        if let value = row[key] {
                            switch value.databaseValue.storage {
                            case .null: try obj.setProperty(key, ctx.undefined())
                            case .blob(let data): try obj.setProperty(key, ctx.data(data))
                            case .double(let number): try obj.setProperty(key, ctx.number(number))
                            case .int64(let number): try obj.setProperty(key, ctx.number(number))
                            case .string(let string): try obj.setProperty(key, ctx.string(string))
                            }
                        }
                    }
                    values.append(obj)
                }
            }
            return values
        }
    }

    private func extractStatementArguments(from arg: JXValue?) throws -> StatementArguments {
        if let arg = arg {
            if arg.isArray {
                return StatementArguments(try arg.array.map({ try $0.asDatabaseValueConvertible }))
            } else if arg.isObject {
                return StatementArguments(try arg.properties.map({ ($0, try arg[$0].asDatabaseValueConvertible) }))
            } else {
                throw JXError(ctx: arg.ctx, value: arg.ctx.string("Bad argument; must be either an array or object"))
            }
        }
        return StatementArguments()
    }
}

extension JXValue {
    /// Converts this type into a `DatabaseValueConvertible`
    var asDatabaseValueConvertible: DatabaseValueConvertible? {
        get throws {
            switch self.type {
            case .none:
                return nil
            case .boolean:
                return self.booleanValue
            case .string:
                return try self.stringValue
            case .number:
                return try self.numberValue
            case .date:
                return try self.dateValue ?? .init(timeIntervalSince1970: 0)
            default:
                throw JXError(ctx: self.ctx, value: self.ctx.string("Unhandled conversion type: \(self.type ?? .boolean)"))
            }
        }
    }
}

final class SQLPodTests: XCTestCase {
    func testSQLPodVersion() {
        XCTAssertLessThanOrEqual(0_000_001, SQLPodVersionNumber)
    }

    func testCreateDatabase() throws {
        let dbpath = "/tmp/\(UUID().uuidString).sqlite"

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

    func testSQLPod() throws {
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
            XCTAssertTrue(try ctx.eval("sql.db()").isObject)

            XCTAssertEqual(9, try ctx.eval("sql.db().query('select 9')").array.first?["9"].numberValue)

            XCTAssertEqual(1, try ctx.eval("sql.db({ readonly: true }).query('select 1 as X')").array.first?["X"].numberValue)

            XCTAssertEqual(1, try ctx.eval("sql.db().query('select ? as X', [1])").array.first?["X"].numberValue)

            let db = try ctx.eval("sql.db()")

            let queryFunction = try db["query"]
            guard queryFunction.isFunction else {
                return XCTFail("query was not a function")
            }


            /// Issues the given SQL statement with the optional argument array
            /// - Parameters:
            ///   - sql: the SQL to execute
            ///   - params: the paramater array to bind to the corresponding '?' statement markers in the SQL
            func query<JX: JXConvertible>(_ sql: String, _ params: [JXConvertible] = []) throws -> [JX] {
                // SQL statement is the first argument, the argument array is the second
                let args = try [ctx.string(sql)] + [ctx.array(params.map({ try $0.getJX(from: ctx) }))]
                return try queryFunction.call(withArguments: args).array.map({ try .makeJX(from: $0) })
            }

            struct DemoRow : Codable, Equatable, JXConvertible {
                var str: String?
                var x, y: Double?
                var dat: Date?
            }

            XCTAssertEqual([DemoRow(str: "QRS")], try query("select 'QRS' as str"))
            XCTAssertEqual([DemoRow(str: "XYZ")], try query("select ? as str", ["XYZ"]))

            XCTAssertEqual([DemoRow(x: 1, y: 2)], try query("select ? as x, ? as y", [1, 2]))
            XCTAssertEqual([DemoRow(x: 1, y: 2), DemoRow(x: 3, y: 4)], try query("select ? as x, ? as y UNION ALL select ? as x, ? as y", [1, 2, 3, 4]))


            XCTAssertEqual([DemoRow(dat: .now)], try query("select CURRENT_TIMESTAMP as dat"))

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
