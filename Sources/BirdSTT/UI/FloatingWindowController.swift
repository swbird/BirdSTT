import AppKit
import SwiftUI

final class FloatingWindowController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?

    func show<Content: View>(content: Content) {
        if panel != nil {
            dismiss(animated: false)
        }

        guard let screen = NSScreen.main else { return }

        let panelWidth: CGFloat = 420
        let panelHeight: CGFloat = 220
        let bottomMargin: CGFloat = 60

        let panelX = (screen.visibleFrame.width - panelWidth) / 2 + screen.visibleFrame.origin.x
        let panelY = screen.visibleFrame.origin.y + bottomMargin

        let panel = NSPanel(
            contentRect: NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true

        let visualEffect = NSVisualEffectView(frame: panel.contentView!.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 20
        visualEffect.layer?.masksToBounds = true
        panel.contentView?.addSubview(visualEffect)

        let hosting = NSHostingView(rootView: AnyView(content))
        hosting.frame = panel.contentView!.bounds
        hosting.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hosting)

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        self.panel = panel
        self.hostingView = hosting
    }

    func dismiss(animated: Bool = true) {
        guard let panel = panel else { return }

        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                panel.orderOut(nil)
                self?.panel = nil
                self?.hostingView = nil
            })
        } else {
            panel.orderOut(nil)
            self.panel = nil
            self.hostingView = nil
        }
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }
}
