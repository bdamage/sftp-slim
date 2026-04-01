import Foundation
import os.log

struct Logger {
    private let logger: os.Logger

    init(subsystem: String) {
        self.logger = os.Logger(subsystem: subsystem, category: "app")
    }

    func info(_ message: String) {
        logger.log(level: .info, "\(message, privacy: .public)")
    }

    func error(_ message: String) {
        logger.log(level: .error, "\(message, privacy: .public)")
    }
}
