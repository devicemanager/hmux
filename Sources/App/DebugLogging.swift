#if DEBUG
import HMUXDebugLog

@inline(__always)
func hmuxDebugLog(_ message: @autoclosure () -> String) {
    HMUXDebugLog.logDebugEvent(message())
}
#endif
