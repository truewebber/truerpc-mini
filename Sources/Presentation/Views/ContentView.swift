import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            List {
                Text("Services")
                Text("Methods")
            }
            .listStyle(SidebarListStyle())
            
            Text("Select a method to start")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}
