import SwiftUI

@main
struct Invader_iOSApp: App {
    private let cpuController: CpuController
    @StateObject private var bitmapProducer: BitmapProducer

    init() {
        let cpuController = CpuController()
        self.cpuController = cpuController
        _bitmapProducer = StateObject(wrappedValue: cpuController.bitmapProducer)
    }

    var body: some Scene {
        WindowGroup {
            InvadersView(bitmapImage: $bitmapProducer.bitmapImage)
                .background(Color(.systemBackground))
                .safeAreaInset(edge: .top, spacing: 8) {
                    ControlPanel(keyInputDelegate: cpuController)
                        .background(.ultraThinMaterial)
                }
                .safeAreaInset(edge: .bottom, spacing: 12) {
                    PlayControl(keyInputDelegate: cpuController)
                        .background(.ultraThinMaterial)
                }
        }
    }
}
