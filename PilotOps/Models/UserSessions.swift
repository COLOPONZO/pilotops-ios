import Foundation

struct UserSession {
    let username: String
    let cookies: [HTTPCookie]
    let loginDate: Date
}
