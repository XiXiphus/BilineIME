import BilinePreview
import Foundation
import XCTest

final class AlibabaOpenAPISignerTests: XCTestCase {
    func testSignerBuildsStableCanonicalRequestAndAuthorization() {
        let signer = AlibabaOpenAPISigner()
        let body = Data("FormatType=text&SourceLanguage=zh".utf8)
        let credentials = AlibabaMachineTranslationCredentials(
            accessKeyId: "testid",
            accessKeySecret: "testsecret"
        )

        let signed = signer.sign(
            host: "mt.aliyuncs.com",
            action: "GetBatchTranslate",
            version: "2018-10-12",
            contentType: "application/x-www-form-urlencoded",
            body: body,
            credentials: credentials,
            date: "2026-04-20T01:00:00Z",
            nonce: "nonce"
        )

        XCTAssertEqual(
            signed.signedHeaders,
            "content-type;host;x-acs-action;x-acs-content-sha256;x-acs-date;x-acs-signature-nonce;x-acs-version"
        )
        XCTAssertEqual(
            signed.hashedPayload,
            "01161f1a336bf74bb54bb1eb1f1d66ca4e1b3a3499e4b8268050e74ab3a81108"
        )
        XCTAssertEqual(
            signed.stringToSign,
            """
            ACS3-HMAC-SHA256
            a61b89dad8dd1f51432ee536f351b9a61405b7065d55e14710c944c88f3feebd
            """
        )
        XCTAssertEqual(
            signed.authorization,
            "ACS3-HMAC-SHA256 Credential=testid,SignedHeaders=content-type;host;x-acs-action;x-acs-content-sha256;x-acs-date;x-acs-signature-nonce;x-acs-version,Signature=ebd147fb2d4987d618d068ccd9eb9d917539de258dc16b29cf5fa2de2e45983d"
        )
    }

    func testPercentEncodingUsesRFC3986SafeSet() {
        XCTAssertEqual(
            AlibabaOpenAPISigner.percentEncode("你好 apple/1"),
            "%E4%BD%A0%E5%A5%BD%20apple%2F1"
        )
    }
}
