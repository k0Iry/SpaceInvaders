import SwiftUI

struct PlayControl: View {
    private let keyInputDelegate: KeyInputControlDelegate?

    init(keyInputDelegate: KeyInputControlDelegate?) {
        self.keyInputDelegate = keyInputDelegate
    }

    var body: some View {
        HStack(spacing: 18) {
            PressPad(
                title: "<",
                fillColor: .blue,
                hapticStyle: .light,
                pressAction: { keyInputDelegate?.press(.left) },
                releaseAction: { keyInputDelegate?.release(.left) }
            )
            PressPad(
                title: "🔥",
                fillColor: .red,
                hapticStyle: .medium,
                pressAction: { keyInputDelegate?.press(.fire) },
                releaseAction: { keyInputDelegate?.release(.fire) }
            )
            PressPad(
                title: ">",
                fillColor: .blue,
                hapticStyle: .light,
                pressAction: { keyInputDelegate?.press(.right) },
                releaseAction: { keyInputDelegate?.release(.right) }
            )
        }
        .frame(maxWidth: 520)
        .padding(.horizontal, 28)
        .padding(.top, 16)
        .padding(.bottom, 22)
    }
}

private struct PressPad: View {
    let title: String
    let fillColor: Color
    let pressAction: () -> Void
    let releaseAction: () -> Void

    @State private var isPressed = false
    private let feedbackGenerator: UIImpactFeedbackGenerator

    init(
        title: String,
        fillColor: Color,
        hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle,
        pressAction: @escaping () -> Void,
        releaseAction: @escaping () -> Void
    ) {
        self.title = title
        self.fillColor = fillColor
        self.pressAction = pressAction
        self.releaseAction = releaseAction
        self.feedbackGenerator = UIImpactFeedbackGenerator(style: hapticStyle)
    }

    var body: some View {
        Text(title)
            .font(.system(size: 28, weight: .semibold, design: .rounded))
            .frame(maxWidth: .infinity)
            .frame(height: 88)
            .foregroundStyle(.primary)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isPressed ? fillColor.opacity(0.40) : fillColor.opacity(0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(fillColor.opacity(0.32), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .onAppear {
                feedbackGenerator.prepare()
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        feedbackGenerator.impactOccurred()
                        feedbackGenerator.prepare()
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
