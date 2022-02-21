import SwiftUI

#if os(iOS)
struct MetalWindow: UIViewRepresentable
{
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MTKView {
        MetalView(context.coordinator);
    }

    func updateUIView(_ nsView: UIViewType, context: Context) {
    }
}
#endif
