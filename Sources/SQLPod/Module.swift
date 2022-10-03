import class Foundation.Bundle
import class Foundation.NSDictionary

// This class supports extracting the version information of the runtime.

// MARK: SQLPod Module Metadata

/// The bundle for the `SQLPod` module.
public let SQLPodBundle = Foundation.Bundle.module

/// The information plist for the `SQLPod` module, which is stored in `Resources/SQLPod.plist` (until SPM supports `Info.plist`).
private let SQLPodPlist = SQLPodBundle.url(forResource: "SQLPod", withExtension: "plist")!

/// The info dictionary for the `SQLPod` module.
public let SQLPodInfo = NSDictionary(contentsOf: SQLPodPlist)

/// The bundle identifier of the `SQLPod` module as specified by the `CFBundleIdentifier` of the `SQLPodInfo`.
public let SQLPodBundleIdentifier: String! = SQLPodInfo?["CFBundleIdentifier"] as? String

/// The version of the `SQLPod` module as specified by the `CFBundleShortVersionString` of the `SQLPodInfo`.
public let SQLPodVersion: String! = SQLPodInfo?["CFBundleShortVersionString"] as? String

/// The version components of the `CFBundleShortVersionString` of the `SQLPodInfo`, such as `[0, 0, 1]` for "0.0.1" ` or `[1, 2]` for "1.2"
private let SQLPodV = { SQLPodVersion.components(separatedBy: .decimalDigits.inverted).compactMap({ Int($0) }).dropFirst($0).first }

/// The major, minor, and patch version components of the `SQLPod` module's `CFBundleShortVersionString`
public let (SQLPodVersionMajor, SQLPodVersionMinor, SQLPodVersionPatch) = (SQLPodV(0), SQLPodV(1), SQLPodV(2))

/// A comparable representation of ``SQLPodVersion``, which can be used for comparing known versions and sorting via semver semantics.
///
/// The form of the number is `(major*1M)+(minor*1K)+patch`, so version "1.2.3" becomes `001_002_003`.
/// Caveat: any minor or patch version components over `999` will break the comparison expectation.
public let SQLPodVersionNumber = ((SQLPodVersionMajor ?? 0) * 1_000_000) + ((SQLPodVersionMinor ?? 0) * 1_000) + (SQLPodVersionPatch ?? 0)
