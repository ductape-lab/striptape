import AppKit
import SwiftUI
import UniformTypeIdentifiers
import StriptapeCore

enum PopoverOpenMode {
    case closed
    case hover
    case click
}

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    static let shared = StatusItemController()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var dropOverlayView: StatusDropView?

    private(set) var openMode: PopoverOpenMode = .closed
    private var hoverCheckTimer: Timer?
    private var hoverExitDeadline: Date?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 260)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: PopoverView(appState: AppState.shared))

        if let button = statusItem.button {
            button.title = "🩹"
            button.target = self
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp])

            // Overlay for hover & drag-and-drop
            let overlay = StatusDropView(frame: button.bounds)
            overlay.autoresizingMask = [.width, .height]
            overlay.controller = self
            button.addSubview(overlay)
            self.dropOverlayView = overlay
        }

        // Global hotkey monitor for paste when popover is open
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
                if self?.popover.isShown == true {
                    AppState.shared.processFromClipboard()
                    return nil
                }
            }
            return event
        }
    }

    // MARK: - Hybrid Pop-up and Pop-out Actions

    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        if openMode == .click {
            // Clicked to pop out
            closePopover()
        } else {
            // Clicked to pop up (or upgrade from hover to clicked/pinned)
            openMode = .click
            stopHoverMonitoring()
            showPopover()
        }
    }

    func handleStatusBarHover() {
        guard AppState.shared.openOnHover else { return }
        if openMode == .closed {
            openMode = .hover
            showPopover()
            startHoverMonitoring()
        }
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func closePopover() {
        stopHoverMonitoring()
        openMode = .closed
        if popover.isShown {
            popover.performClose(nil)
        }
    }

    // MARK: - Hover Monitoring for Pop-out on Hover-off

    private func startHoverMonitoring() {
        hoverCheckTimer?.invalidate()
        hoverExitDeadline = nil
        hoverCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkHoverStatus()
            }
        }
    }

    private func stopHoverMonitoring() {
        hoverCheckTimer?.invalidate()
        hoverCheckTimer = nil
        hoverExitDeadline = nil
    }

    private func checkHoverStatus() {
        guard openMode == .hover, popover.isShown else {
            stopHoverMonitoring()
            return
        }

        let mouseScreenLocation = NSEvent.mouseLocation

        // 1. Check if mouse is over the menu bar status button (with generous padding for gap bridge)
        var isOverButton = false
        if let button = statusItem.button, let window = button.window {
            let buttonRectInWindow = button.convert(button.bounds, to: nil)
            let buttonScreenRect = window.convertToScreen(buttonRectInWindow)
            if buttonScreenRect.insetBy(dx: -6, dy: -8).contains(mouseScreenLocation) {
                isOverButton = true
            }
        }

        // 2. Check if mouse is over the popover content window
        var isOverPopover = false
        if let popoverWindow = popover.contentViewController?.view.window {
            let popoverScreenRect = popoverWindow.frame.insetBy(dx: -6, dy: -8)
            if popoverScreenRect.contains(mouseScreenLocation) {
                isOverPopover = true
            }
        }

        if isOverButton || isOverPopover {
            // Still hovering over the app
            hoverExitDeadline = nil
        } else {
            // Hovered off!
            if hoverExitDeadline == nil {
                // Short 200ms grace period so rapid cross-border motion doesn't flicker
                hoverExitDeadline = Date().addingTimeInterval(0.2)
            } else if Date() >= hoverExitDeadline! {
                closePopover()
            }
        }
    }

    // MARK: - NSPopoverDelegate

    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor in
            self.openMode = .closed
            self.stopHoverMonitoring()
        }
    }
}

final class StatusDropView: NSView {
    weak var controller: StatusItemController?
    private var trackingArea: NSTrackingArea?
    private var isDragOver: Bool = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .tiff, .png])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .tiff, .png])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        Task { @MainActor in
            controller?.handleStatusBarHover()
        }
    }

    // Pass clicks down to parent NSStatusBarButton
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    // Drag-and-drop onto menu bar icon directly
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        isDragOver = true
        needsDisplay = true
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDragOver = false
        needsDisplay = true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDragOver = false
        needsDisplay = true

        let pasteboard = sender.draggingPasteboard
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let url = urls.first {
            Task { @MainActor in
                AppState.shared.processFile(at: url)
                controller?.showPopover()
            }
            return true
        }

        if let image = NSImage(pasteboard: pasteboard), let tiff = image.tiffRepresentation {
            Task { @MainActor in
                AppState.shared.processData(tiff, filename: "dragged_image")
                controller?.showPopover()
            }
            return true
        }

        return false
    }
}
