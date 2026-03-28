import SwiftUI

struct MainTabView: View {
    @State private var selected = 0

    var body: some View {
        TabView(selection: $selected) {
            WorkoutsPaneView()
                .tabItem { Label("Train", systemImage: "figure.strengthtraining.traditional") }
                .tag(0)

            DietPaneView()
                .tabItem { Label("Fuel", systemImage: "leaf.fill") }
                .tag(1)

            ProgressOverviewView()
                .tabItem { Label("Focus", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(2)

            ShareExportView()
                .tabItem { Label("Share", systemImage: "square.and.arrow.up") }
                .tag(3)
        }
        .toolbarBackground(FocusPalette.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
