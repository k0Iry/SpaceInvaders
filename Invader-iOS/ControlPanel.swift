import SwiftUI

struct ControlPanel: View {
    private let keyInputDelegate: KeyInputControlDelegate?

    @State private var startButtonTitle = "▶"

    init(keyInputDelegate: KeyInputControlDelegate?) {
        self.keyInputDelegate = keyInputDelegate
    }

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                Button(startButtonTitle) {
                    keyInputDelegate?.press(.pause)
                    startButtonTitle = startButtonTitle == "▶" ? "▶॥" : "▶"
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("↻") {
                    keyInputDelegate?.press(.restart)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                HoldActionButton(
                    title: "💰",
                    pressAction: { keyInputDelegate?.press(.coin) },
                    releaseAction: { keyInputDelegate?.release(.coin) }
                )
                HoldActionButton(
                    title: "👾",
                    pressAction: { keyInputDelegate?.press(.start) },
                    releaseAction: { keyInputDelegate?.release(.start) }
                )
            }
        }
        .frame(maxWidth: 520)
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
}

private struct HoldActionButton: View {
    let title: String
    let pressAction: () -> Void
    let releaseAction: () -> Void

    @State private var isPressed = false

    var body: some View {
        Text(title)
            .font(.title2)
            .frame(width: 56, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isPressed ? Color.secondary.opacity(0.30) : Color.secondary.opacity(0.16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.secondary.opacity(0.20), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        pressAction()
                    }
                    .onEnded { _ in
                        guard isPressed else { return }
                        isPressed = false
                        releaseAction()
                    }
            )
    }
}
