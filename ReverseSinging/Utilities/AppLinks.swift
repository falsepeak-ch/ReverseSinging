//
//  AppLinks.swift
//  ReverseSinging
//
//  Every address the app sends people to, in one place
//

import Foundation

/// The web pages and addresses the app links to. Dubloon's own policy and terms live on its
/// site, written for this app rather than the studio's generic pages.
nonisolated enum AppLinks {
    static let website = URL(string: "https://reverso-87e1a.web.app")!
    static let privacyPolicy = URL(string: "https://reverso-87e1a.web.app/privacy")!
    static let termsOfUse = URL(string: "https://reverso-87e1a.web.app/terms")!
    static let supportEmail = "contact@falsepeak.ch"

    /// A new email to support, with what we need to help already filled in: the app and system
    /// versions and the device. Nothing else about the person or their recordings.
    static func supportMail(subject: String, details: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: "\n\n\n—\n\(details)")
        ]
        return components.url
    }
}
