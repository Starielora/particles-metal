import SwiftUI
import MetalKit

struct ContentView: View
{
    var body: some View
    {
        MetalWindow()
    }
}

struct ContentView_Provider: PreviewProvider
{
    static var previews: some View
    {
        Group
        {
            ContentView();
        }
    }
}
