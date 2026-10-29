import AppKit
import SwiftUI
import UniformTypeIdentifiers
import StriptapeCore

@MainActor
final class StatusItemController: NSObject {
    static let shared = StatusItemController()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var dropOverlayView: StatusDropView?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 260)
        popover.behavior = .transient
        popover.animates = true
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

    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        togglePopover(sender: sender)
    }

    func togglePopover(sender: Any?) {
        guard statusItem.button != nil else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover(sender: sender)
        }
    }

    func showPopover(sender: Any?) {
        guard let button = statusItem.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func hidePopover() {
        if popover.isShown {
            popover.performClose(nil)
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
            if AppState.shared.openOnHover {
                controller?.showPopover(sender: self)
            }
        }
    }

    // Pass clicks down to parent NSStatusBarButton
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Allow clicks to go straight through to NSStatusBarButton for native highlight/click
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
                controller?.showPopover(sender: self)
            }
            return true
        }

        if let image = NSImage(pasteboard: pasteboard), let tiff = image.tiffRepresentation {
            Task { @MainActor in
                AppState.shared.processData(tiff, filename: "dragged_image")
                controller?.showPopover(sender: self)
            }
            return true
        }

        return false
    }
}
