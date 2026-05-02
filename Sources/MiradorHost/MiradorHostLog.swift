import OSLog

enum MiradorHostLog {
    static let network = Logger(subsystem: "com.stevenacz.mirador", category: "host.network")
    static let stream = Logger(subsystem: "com.stevenacz.mirador", category: "host.stream")
    static let input = Logger(subsystem: "com.stevenacz.mirador", category: "host.input")
    static let permission = Logger(subsystem: "com.stevenacz.mirador", category: "host.permission")
}
