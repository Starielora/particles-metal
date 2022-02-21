#if os(iOS)
class MetalView: MTKView
{
    var renderer: RendererWrapper?

    init(_ coordinator: Coordinator)
    {
        guard let gpu = MTLCreateSystemDefaultDevice() else {
            fatalError("Could not create gpu");
        }
        super.init(frame: UIScreen.main.bounds, device: gpu)

        super.delegate = coordinator;
        super.preferredFramesPerSecond = 120
        super.enableSetNeedsDisplay = true;
        super.framebufferOnly = false;
        super.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1);
        super.isPaused = false;

        renderer = RendererWrapper(device: gpu, view: self)
        coordinator.renderer = renderer
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let x = Double(touch.location(in: self).x)
            let y = Double(touch.location(in: self).y)
            renderer!.setEmitPos(x, y)
            renderer!.toggleShouldEmit()
            renderer!.forwardEvent(toImGui: event);
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        renderer!.toggleShouldEmit()
        renderer!.forwardEvent(toImGui: event);
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let x = Double(touch.location(in: self).x)
            let y = Double(touch.location(in: self).y)
            renderer!.setEmitPos(x, y)
            renderer!.forwardEvent(toImGui: event);
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        renderer!.forwardEvent(toImGui: event);
    }
}
#endif
