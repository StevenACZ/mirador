import OSLog

enum MiradorClientLog {
    static let browser = Logger(subsystem: "com.stevenacz.mirador", category: "client.browser")
    static let connection = Logger(subsystem: "com.stevenacz.mirador", category: "client.connection")
    static let stream = Logger(subsystem: "com.stevenacz.mirador", category: "client.stream")
    static let input = Logger(subsystem: "com.stevenacz.mirador", category: "client.input")
}
