import SwiftUI

@main
struct Invader_iOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let cpuController: CpuController
    private let videoFramePipeline: VideoFramePipeline

    init() {
        let displayRefreshMode: DisplayRefreshMode = .original60

        let cpuController = CpuController(refreshMode: displayRefreshMode)
        self.cpuController = cpuController
        self.videoFramePipeline = cpuController.videoFramePipeline
    }

    var body: some Scene {
        WindowGroup {
            InvadersView(videoFramePipeline: videoFramePipeline)
                .background(Color(.systemBackground))
                .safeAreaInset(edge: .top, spacing: 8) {
                    ControlPanel(keyInputDelegate: cpuController)
                        .background(.ultraThinMaterial)
                }
                .safeAreaInset(edge: .bottom, spacing: 12) {
                    PlayControl(keyInputDelegate: cpuController)
                        .background(.ultraThinMaterial)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .inactive, .background:
                        cpuController.persistHighScore()
                    default:
                        break
                    }
                }
        }
    }
}
