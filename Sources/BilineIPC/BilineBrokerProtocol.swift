import Foundation

@objc public protocol BilineBrokerXPCProtocol {
    func ping(_ reply: @escaping (String) -> Void)
    func fetchConfiguration(_ reply: @escaping (Data?, String?) -> Void)
    func storeConfiguration(_ data: Data, reply: @escaping (String?) -> Void)
    func fetchCredentialStatus(_ reply: @escaping (Data?, String?) -> Void)
    func loadCredentialRecord(_ reply: @escaping (Data?, String?) -> Void)
    func saveCredentialRecord(_ data: Data, reply: @escaping (String?) -> Void)
    func clearCredentialRecord(_ reply: @escaping (String?) -> Void)
    func fetchDiagnostics(_ reply: @escaping (Data?, String?) -> Void)
}
