import class Foundation.Bundle

extension Foundation.Bundle {
    static var module: Bundle = {
        let mainPath = Bundle.main.bundleURL.appendingPathComponent("SQLEnclave_SQLEnclave.bundle").path
        let buildPath = "/Users/runner/work/SQLPod/SQLPod/.build/x86_64-apple-macosx/debug/SQLEnclave_SQLEnclave.bundle"

        let preferredBundle = Bundle(path: mainPath)

        guard let bundle = preferredBundle ?? Bundle(path: buildPath) else {
            fatalError("could not load resource bundle: from \(mainPath) or \(buildPath)")
        }

        return bundle
    }()
}