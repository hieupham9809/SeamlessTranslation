import SwiftUI
struct OverlayView: View {
    @StateObject private var viewModel = OverlayViewModel()
    @State private var pickerSize: CGSize = .zero
    @State private var contentSize: CGSize = .zero

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // Empty space to account for the picker that will overlay this area
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: pickerSize.height)
                
                if viewModel.selectedTab == 0 {
                    TranslateView(viewModel: viewModel)
                        .size { contentSize = $0 }
                        .transition(.move(edge: .leading))
                } else {
                    SettingsView(viewModel: viewModel)
                        .size { contentSize = $0 }
                        .transition(.move(edge: .trailing))
                    Spacer()
                }
            }
            .frame(height: contentSize.height + pickerSize.height)

            // Picker is placed in the ZStack to always stay on top
            Picker("Options", selection: $viewModel.selectedTab) {
                Text("Translate").tag(0)
                Text("Settings").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            .size { pickerSize = $0 }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .animation(.linear, value: viewModel.selectedTab)
    }
}

struct OverlayView_Previews: PreviewProvider {
    static var previews: some View {
        OverlayView()
    }
}
