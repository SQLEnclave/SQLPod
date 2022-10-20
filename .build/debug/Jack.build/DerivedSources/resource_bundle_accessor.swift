import class Foundation.Bundle

extension Foundation.Bundle {
    static var module: Bundle = {
        let mainPath = Bundle.main.bundleURL.appendingPathComponent("Jack_Jack.bundle").path
        let buildPath = "/Users/runner/work/SQLPod/SQLPod/.build/x86_64-apple-macosx/debug/Jack_Jack.bundle"

        let preferredBundle = Bundle(path: mainPath)

        guard let bundle = preferredBundle ?? Bundle(path: buildPath) else {
            fatalError("could not load resource bundle: from \(mainPath) or \(buildPath)")
        }

        return bundle
    }()
}