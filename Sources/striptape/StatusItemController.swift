import AppKit
import SwiftUI
import Combine
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
    private var pulseCancellable: AnyCancellable?

    private(set) var openMode: PopoverOpenMode = .closed
    private var hoverOpenTimer: Timer?
    private var hoverCheckTimer: Timer?
    private var hoverExitDeadline: Date?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let hostingController = NSHostingController(rootView: PopoverView(appState: AppState.shared))
        hostingController.sizingOptions = []
        hostingController.view.wantsLayer = true
        hostingController.view.layerContentsRedrawPolicy = .onSetNeedsDisplay
        hostingController.view.layoutSubtreeIfNeeded()

        popover = NSPopover()
        popover.contentSize = NSSize(width: 314, height: 260)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = hostingController

        if let button = statusItem.button {
            updateStatusButtonIcon(success: false)
            button.target = self
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseDown])

            // Overlay for hover & drag-and-drop
            let overlay = StatusDropView(frame: button.bounds)
            overlay.autoresizingMask = [.width, .height]
            overlay.controller = self
            button.addSubview(overlay)
            self.dropOverlayView = overlay
        }

        pulseCancellable = AppState.shared.$statusBarPulse
            .removeDuplicates()
            .sink { [weak self] pulsed in
                self?.updateStatusButtonIcon(success: pulsed)
            }

        // Local hotkey monitor for ⌘V (paste), ⌘C (copy), ⌘Q (quit), Esc (close) when popover is open
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard self?.popover.isShown == true else { return event }

            if event.keyCode == 53 { // Escape
                self?.closePopover()
                return nil
            }

            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  let key = event.charactersIgnoringModifiers?.lowercased() else {
                return event
            }

            if key == "v" {
                AppState.shared.processFromClipboard()
                return nil
            } else if key == "c", AppState.shared.currentResult != nil {
                AppState.shared.copyCleanedImageToClipboard()
                return nil
            } else if key == "q" {
                NSApplication.shared.terminate(nil)
                return nil
            }
            return event
        }
    }

    private func updateStatusButtonIcon(success: Bool) {
        guard let button = statusItem.button else { return }
        let symbolName = success ? "checkmark.circle.fill" : "bandage.fill"
        let config = NSImage.SymbolConfiguration(pointSize: 13.5, weight: .medium)
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "striptape")?.withSymbolConfiguration(config) {
            image.isTemplate = true
            button.image = image
            button.title = ""
        } else {
            button.title = "🩹"
        }
    }

    // MARK: - Hybrid Pop-up and Pop-out Actions

    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        cancelPendingHoverOpen()

        let mode = AppState.shared.menuTriggerMode
        if mode == .hover {
            if popover.isShown {
                closePopover()
            }
            return
        }

        if popover.isShown {
            closePopover()
        } else {
            openMode = .click
            stopHoverMonitoring()
            showPopover()
        }
    }

    func handleStatusBarHoverEnter() {
        let mode = AppState.shared.menuTriggerMode
        guard mode != .click, openMode == .closed, !popover.isShown else { return }
        cancelPendingHoverOpen()
        let dwellTime: TimeInterval = (mode == .hover) ? 0.25 : 0.45
        hoverOpenTimer = Timer.scheduledTimer(withTimeInterval: dwellTime, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.openMode == .closed, !self.popover.isShown else { return }
                self.openMode = .hover
                self.showPopover()
                self.startHoverMonitoring()
            }
        }
    }

    func handleStatusBarHoverExit() {
        cancelPendingHoverOpen()
    }

    private func cancelPendingHoverOpen() {
        hoverOpenTimer?.invalidate()
        hoverOpenTimer = nil
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        if !popover.isShown {
            popover.contentViewController?.view.layoutSubtreeIfNeeded()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func closePopover() {
        cancelPendingHoverOpen()
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
        hoverCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
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

    private static let supportedDraggedTypes: [NSPasteboard.PasteboardType] = [
        .fileURL,
        .png,
        NSPasteboard.PasteboardType(UTType.jpeg.identifier),
        NSPasteboard.PasteboardType(UTType.webP.identifier),
        NSPasteboard.PasteboardType(UTType.heic.identifier),
        .tiff
    ]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(Self.supportedDraggedTypes)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes(Self.supportedDraggedTypes)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        MainActor.assumeIsolated {
            controller?.handleStatusBarHoverEnter()
        }
    }

    override func mouseExited(with event: NSEvent) {
        MainActor.assumeIsolated {
            controller?.handleStatusBarHoverExit()
        }
    }

    // Pass clicks down to parent NSStatusBarButton
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    // Drag-and-drop onto menu bar icon directly
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        MainActor.assumeIsolated {
            AppState.shared.triggerHaptic(.alignment)
        }
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let url = urls.first {
            MainActor.assumeIsolated {
                AppState.shared.processFile(at: url)
                controller?.showPopover()
            }
            return true
        }

        for type in Self.supportedDraggedTypes where type != .fileURL {
            if let data = pasteboard.data(forType: type) {
                MainActor.assumeIsolated {
                    AppState.shared.processData(data, filename: nil)
                    controller?.showPopover()
                }
                return true
            }
        }

        if let image = NSImage(pasteboard: pasteboard), let tiff = image.tiffRepresentation {
            MainActor.assumeIsolated {
                AppState.shared.processData(tiff, filename: nil)
                controller?.showPopover()
            }
            return true
        }

        return false
    }
}
