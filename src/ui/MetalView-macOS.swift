#if os(macOS)
class MetalView: MTKView
{
    var renderer: RendererWrapper?
    var trackingArea : NSTrackingArea?

    init(_ coordinator: Coordinator)
    {
        guard let gpu = MTLCreateSystemDefaultDevice() else {
            fatalError("Could not create gpu");
        }
        super.init(frame: NSScreen.main!.frame, device: gpu)
        super.delegate = coordinator;
        super.preferredFramesPerSecond = 120
        super.enableSetNeedsDisplay = true;
        super.framebufferOnly = false;
        super.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1);
        super.isPaused = false;

        renderer = RendererWrapper(device: gpu, view: self)
        coordinator.renderer = renderer
    }

    override func updateTrackingAreas() {
        if trackingArea != nil {
            self.removeTrackingArea(trackingArea!)
        }
        let options : NSTrackingArea.Options =
        [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow]
        trackingArea = NSTrackingArea(rect: self.bounds, options: options,
                                      owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea!)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseMoved(with event: NSEvent) {
        renderer!.forwardEvent(toImGui: event)
    }

    override func mouseUp(with event: NSEvent) {
        renderer!.forwardEvent(toImGui: event)
    }

    override func mouseDragged(with event: NSEvent) {
        renderer!.forwardEvent(toImGui: event)
    }

    override func mouseDown(with event: NSEvent) {
        renderer!.forwardEvent(toImGui: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        renderer!.setEmitPos(Double(event.locationInWindow.x), Double(event.locationInWindow.y))
        renderer!.toggleShouldEmit()
    }

    override func rightMouseDragged(with event: NSEvent) {
        renderer!.setEmitPos(Double(event.locationInWindow.x), Double(event.locationInWindow.y))
        renderer!.forwardEvent(toImGui: event)
    }

    override func rightMouseUp(with event: NSEvent) {
        renderer!.toggleShouldEmit()
        renderer!.forwardEvent(toImGui: event)
    }

    override func keyDown(with event: NSEvent) {
        renderer!.forwardEvent(toImGui: event)
        if (event.keyCode == 13) // W
        {

        }
        else if (event.keyCode == 1) // S
        {

        }
        else if (event.keyCode == 0) // A
        {

        }
        else if (event.keyCode == 2) // D
        {

        }
        else
        {
            print(event.keyCode)
        }
    }

    override func keyUp(with event: NSEvent) {
        if (event.keyCode == 53) // esc
        {
            event.window?.close()
        }
        else if (event.keyCode == 13) // W
        {

        }
        else if (event.keyCode == 1) // S
        {

        }
        else if (event.keyCode == 0) // A
        {

        }
        else if (event.keyCode == 2) // D
        {

        }
        else
        {
            print(event.keyCode)
        }
    }

    override var acceptsFirstResponder: Bool {
        return true;
    }
}
#endif
