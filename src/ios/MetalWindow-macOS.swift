#if os(macOS)
import SwiftUI

struct MetalWindow: NSViewRepresentable
{
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> MTKView {
        MetalView(context.coordinator);
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {
    }
}
#endif
