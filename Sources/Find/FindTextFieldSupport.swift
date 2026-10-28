import AppKit

enum FindFocusNotificationKey {
    static let selectAll = "hmux.find.selectAll"
}

func hmuxClampedFindSelection(_ range: NSRange, in text: String) -> NSRange {
    let textLength = text.utf16.count
    guard range.location != NSNotFound else {
        return NSRange(location: textLength, length: 0)
    }
    let location = min(max(range.location, 0), textLength)
    let length = min(max(range.length, 0), textLength - location)
    return NSRange(location: location, length: length)
}

func hmuxTextFieldIsFirstResponder(_ field: NSTextField, in window: NSWindow) -> Bool {
    let firstResponder = window.firstResponder
    if firstResponder === field { return true }
    if let editor = field.currentEditor() as? NSTextView, firstResponder === editor { return true }
    return (firstResponder as? NSTextView).flatMap { hmuxFieldEditorOwnerView($0) } === field
}

private let hmuxFindSelectionChangingCommands: Set<String> = [
    "moveLeft:",
    "moveRight:",
    "moveBackward:",
    "moveForward:",
    "moveUp:",
    "moveDown:",
    "moveWordLeft:",
    "moveWordRight:",
    "moveWordBackward:",
    "moveWordForward:",
    "moveToBeginningOfLine:",
    "moveToEndOfLine:",
    "moveToBeginningOfDocument:",
    "moveToEndOfDocument:",
    "moveLeftAndModifySelection:",
    "moveRightAndModifySelection:",
    "moveBackwardAndModifySelection:",
    "moveForwardAndModifySelection:",
    "moveUpAndModifySelection:",
    "moveDownAndModifySelection:",
    "moveWordLeftAndModifySelection:",
    "moveWordRightAndModifySelection:",
    "moveWordBackwardAndModifySelection:",
    "moveWordForwardAndModifySelection:",
    "moveToBeginningOfLineAndModifySelection:",
    "moveToEndOfLineAndModifySelection:",
    "moveToBeginningOfDocumentAndModifySelection:",
    "moveToEndOfDocumentAndModifySelection:",
    "selectAll:",
]

func hmuxFindCommandMayChangeSelection(_ selector: Selector) -> Bool {
    hmuxFindSelectionChangingCommands.contains(NSStringFromSelector(selector))
}

func hmuxFindEventIsPlainEscape(_ event: NSEvent) -> Bool {
    ShortcutStroke.normalizedModifierFlags(from: event.modifierFlags).isEmpty && ShortcutStroke.isEscapeCancelEvent(event)
}

private let hmuxFindSelectionStore = NSMapTable<AnyObject, NSValue>.weakToStrongObjects()
private let hmuxFindFieldEditorOwners = NSMapTable<NSTextView, FindSelectionTrackingTextField>.weakToWeakObjects()

func hmuxStoredFindSelection(for owner: AnyObject?) -> NSRange? {
    guard let owner else { return nil }
    return hmuxFindSelectionStore.object(forKey: owner)?.rangeValue
}

func hmuxStoreFindSelection(_ range: NSRange, for owner: AnyObject?) {
    guard let owner else { return }
    hmuxFindSelectionStore.setObject(NSValue(range: range), forKey: owner)
}

func hmuxTrackedFindFieldEditorOwner(_ editor: NSTextView) -> FindSelectionTrackingTextField? {
    guard editor.isFieldEditor else { return nil }
    return hmuxFindFieldEditorOwners.object(forKey: editor)
}

func hmuxFindTextFieldOwner(for responder: NSResponder?) -> FindSelectionTrackingTextField? {
    if let field = responder as? FindSelectionTrackingTextField {
        return field
    }
    if let editor = responder as? NSTextView {
        return hmuxTrackedFindFieldEditorOwner(editor) ?? (hmuxFieldEditorOwnerView(editor) as? FindSelectionTrackingTextField)
    }
    return nil
}

@MainActor
func hmuxRememberFindSelectionBeforePanelFocusMove(tabManager: TabManager?, window: NSWindow?) {
    guard let editor = window?.firstResponder as? NSTextView else { return }
    let selection = hmuxClampedFindSelection(editor.selectedRange(), in: editor.string)
    if let field = hmuxTrackedFindFieldEditorOwner(editor),
       let owner = field.hmuxSelectionOwner {
        _ = field.hmuxRememberSelection(selection, in: editor.string)
        hmuxStoreFindSelection(selection, for: owner)
        return
    }
    guard let workspace = tabManager?.selectedWorkspace,
          let focusedPanelId = workspace.focusedPanelId else { return }
    let owner = (workspace.focusedTerminalInputTarget()?.panel.searchState as AnyObject?)
        ?? (workspace.browserPanel(for: focusedPanelId)?.searchState as AnyObject?)
    guard let owner else { return }
    hmuxStoreFindSelection(selection, for: owner)
}

@discardableResult
func hmuxApplyFindFocusSelection(
    field: FindSelectionTrackingTextField,
    selectAll: Bool,
    alreadyFocused: Bool,
    rememberedRange: NSRange?
) -> NSRange? {
    guard let editor = field.currentEditor() as? NSTextView, !editor.hasMarkedText() else { return nil }
    if selectAll {
        let selection = field.hmuxRememberSelection(NSRange(location: 0, length: editor.string.utf16.count), in: editor.string)
        editor.setSelectedRange(selection)
        return selection
    }
    guard !alreadyFocused, let rememberedRange else { return nil }
    let selection = field.hmuxRememberSelection(rememberedRange, in: editor.string)
    editor.setSelectedRange(selection)
    return selection
}

@discardableResult
func hmuxRememberFindSelection(in root: NSView?) -> NSRange? {
    guard let root else { return nil }
    if let field = root as? FindSelectionTrackingTextField,
       let selection = field.hmuxRememberSelectionFromCurrentEditor() {
        return selection
    }
    for subview in root.subviews {
        if let selection = hmuxRememberFindSelection(in: subview) {
            return selection
        }
    }
    return nil
}

func hmuxFindResponderSnapshot() -> [String: String] {
    let responder = (NSApp.keyWindow ?? NSApp.mainWindow)?.firstResponder
    var updates: [String: String] = [
        "firstResponderType": responder.map { String(describing: type(of: $0)) } ?? "",
        "firstResponderIdentifier": (responder as? NSView)?.identifier?.rawValue ?? "",
    ]
    if let textView = responder as? NSTextView {
        updates["firstResponderSelectedRange"] = NSStringFromRange(textView.selectedRange())
        if let owner = hmuxFieldEditorOwnerView(textView) {
            updates["fieldEditorOwnerType"] = String(describing: type(of: owner))
            updates["fieldEditorOwnerIdentifier"] = owner.identifier?.rawValue ?? ""
        }
    }
    return updates
}

class FindSelectionTrackingTextField: NSTextField {
    var hmuxLastSelectedRange: NSRange?
    weak var hmuxSelectionOwner: AnyObject?
    var hmuxOnEscape: ((NSTextView) -> Bool)?
    /// Reports whether the field is actually being edited: true once it takes
    /// first responder, false when its field editor ends editing. Drives the
    /// focus stroke, which must not follow a focus request that never landed.
    var hmuxOnEditingChanged: ((Bool) -> Void)?
    private var hmuxSelectionObserver: NSObjectProtocol?
    private var hmuxKeyMonitor: Any?
    private weak var hmuxObservedEditor: NSTextView?
    private weak var hmuxPreviousEditorNextResponder: NSResponder?

    deinit {
        hmuxDetachSelectionObserver()
        hmuxRemoveKeyMonitor()
    }

    override func becomeFirstResponder() -> Bool {
        guard super.becomeFirstResponder() else { return false }
        hmuxAttachSelectionObserverIfNeeded()
        hmuxRestoreRememberedSelection()
        hmuxOnEditingChanged?(true)
        return true
    }

    override func textDidBeginEditing(_ notification: Notification) {
        super.textDidBeginEditing(notification)
        hmuxAttachSelectionObserverIfNeeded()
        hmuxInstallKeyMonitorIfNeeded()
        if hmuxLastSelectedRange == nil, hmuxStoredFindSelection(for: hmuxSelectionOwner) == nil {
            _ = hmuxRememberSelectionFromCurrentEditor()
        }
    }

    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        _ = hmuxRememberSelectionFromCurrentEditor()
    }

    override func textDidEndEditing(_ notification: Notification) {
        _ = hmuxRememberSelectionFromCurrentEditor()
        hmuxRemoveKeyMonitor()
        hmuxDetachSelectionObserver()
        super.textDidEndEditing(notification)
        hmuxOnEditingChanged?(false)
    }

    override func cancelOperation(_ sender: Any?) {
        if let editor = currentEditor() as? NSTextView, !editor.hasMarkedText(), hmuxOnEscape?(editor) == true {
            return
        }
        super.cancelOperation(sender)
    }

    func hmuxRememberSelection(_ range: NSRange, in text: String) -> NSRange {
        let selection = hmuxClampedFindSelection(range, in: text)
        hmuxLastSelectedRange = selection
        hmuxStoreFindSelection(selection, for: hmuxSelectionOwner)
        return selection
    }

    func hmuxRememberSelection(from textView: NSTextView) -> NSRange {
        hmuxRememberSelection(textView.selectedRange(), in: textView.string)
    }

    func hmuxRememberSelectionFromCurrentEditor() -> NSRange? {
        guard let editor = currentEditor() as? NSTextView else { return nil }
        return hmuxRememberSelection(from: editor)
    }

    private func hmuxAttachSelectionObserverIfNeeded() {
        guard let editor = currentEditor() as? NSTextView else { return }
        if let hmuxObservedEditor, hmuxObservedEditor !== editor {
            hmuxDetachSelectionObserver()
        }
        hmuxAdoptFieldEditor(editor)
        guard hmuxSelectionObserver == nil else { return }
        hmuxSelectionObserver = NotificationCenter.default.addObserver(
            forName: NSTextView.didChangeSelectionNotification,
            object: editor,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let textView = notification.object as? NSTextView else { return }
            _ = self.hmuxRememberSelection(from: textView)
        }
    }

    private func hmuxDetachSelectionObserver() {
        if let hmuxSelectionObserver {
            NotificationCenter.default.removeObserver(hmuxSelectionObserver)
            self.hmuxSelectionObserver = nil
        }
        if let editor = hmuxObservedEditor {
            if editor.nextResponder === self {
                editor.nextResponder = hmuxPreviousEditorNextResponder
            }
            if hmuxTrackedFindFieldEditorOwner(editor) === self {
                hmuxFindFieldEditorOwners.removeObject(forKey: editor)
            }
        }
        hmuxPreviousEditorNextResponder = nil
        hmuxObservedEditor = nil
    }

    private func hmuxAdoptFieldEditor(_ editor: NSTextView) {
        hmuxObservedEditor = editor
        hmuxFindFieldEditorOwners.setObject(self, forKey: editor)
        if editor.nextResponder !== self {
            hmuxPreviousEditorNextResponder = editor.nextResponder
            editor.nextResponder = self
        }
        hmuxInstallKeyMonitorIfNeeded()
    }

    private func hmuxInstallKeyMonitorIfNeeded() {
        guard hmuxKeyMonitor == nil else { return }
        hmuxKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let eventWindow = event.window ?? (event.windowNumber > 0 ? NSApp.window(withWindowNumber: event.windowNumber) : nil)
            guard let self,
                  eventWindow == nil || eventWindow === self.window,
                  let editor = self.currentEditor() as? NSTextView,
                  self.window?.firstResponder === editor else { return event }
            if hmuxFindEventIsPlainEscape(event), !editor.hasMarkedText(), self.hmuxOnEscape?(editor) == true { return nil }
            DispatchQueue.main.async { [weak self, weak editor] in
                guard let self, let editor else { return }
                _ = self.hmuxRememberSelection(from: editor)
            }
            return event
        }
    }

    private func hmuxRemoveKeyMonitor() {
        if let hmuxKeyMonitor {
            NSEvent.removeMonitor(hmuxKeyMonitor)
            self.hmuxKeyMonitor = nil
        }
    }

    private func hmuxRestoreRememberedSelection() {
        guard let rememberedSelection = hmuxStoredFindSelection(for: hmuxSelectionOwner) ?? hmuxLastSelectedRange else { return }
        if let editor = currentEditor() as? NSTextView, !editor.hasMarkedText() {
            let selection = hmuxRememberSelection(rememberedSelection, in: editor.string)
            editor.setSelectedRange(selection)
        }
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let editor = self.currentEditor() as? NSTextView,
                  !editor.hasMarkedText() else { return }
            let selection = self.hmuxRememberSelection(rememberedSelection, in: editor.string)
            editor.setSelectedRange(selection)
        }
    }
}
