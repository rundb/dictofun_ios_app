import Foundation

class PrintLogger: Logger {
    func log(level aLevel: LogType, message aMessage: String) {
        let date = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minutes = calendar.component(.minute, from: date)
        let seconds = calendar.component(.second, from: date)
        let nanosecond = calendar.component(.nanosecond, from: date)
        print("\(hour):\(minutes):\(seconds):\(nanosecond) [\(aLevel.rawValue)] \(aMessage)")
    }
    
}
