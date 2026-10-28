import Foundation

extension Notification.Name {
    /// Posted when the signed-in session's Cloud VM access ends (sign-out or account switch).
    public static let hmuxCloudVMAccessDidEnd = Notification.Name("hmux.cloudVM.accessDidEnd")
}
