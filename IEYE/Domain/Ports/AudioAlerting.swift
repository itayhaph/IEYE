import Foundation

public protocol AudioAlerting: AnyObject {
    func playWarning()
    func playAlarm()
    func stop()
}
