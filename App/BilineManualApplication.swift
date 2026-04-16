import Cocoa

final class BilineManualApplication: NSApplication {
    private let bilineAppDelegate = BilineAppDelegate()

    override init() {
        super.init()
        delegate = bilineAppDelegate
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
