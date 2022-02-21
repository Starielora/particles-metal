class Coordinator: NSObject, MTKViewDelegate
{
    var parent: MetalWindow
    var renderer: RendererWrapper?

    init(_ parent: MetalWindow)
    {
        self.parent = parent
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer!.setWindowSize(Float(size.width), Float(size.height));
    }

    func draw(in view: MTKView) {
        renderer!.draw(view);
    }
}
