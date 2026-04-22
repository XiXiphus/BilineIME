import BilineIPC
import BilineSettings
import Dispatch
import Foundation

final class BilineBrokerListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let service = BilineBrokerService()

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: BilineBrokerXPCProtocol.self)
        newConnection.exportedObject = service
        newConnection.resume()
        return true
    }
}

let listener = NSXPCListener(
    machServiceName: BilineSharedIdentifier.brokerMachServiceName(
        for: BilineAppIdentifier.devInputMethodBundle
    )
)
let delegate = BilineBrokerListenerDelegate()
listener.delegate = delegate
listener.resume()
dispatchMain()
