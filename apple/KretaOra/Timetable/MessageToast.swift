import SwiftUI

/// A short notice above the home indicator that goes away on its own or on a tap.
struct MessageToast: View {
    let text: String?
    let onDismiss: () -> Void

    private static let visibleFor: Duration = .seconds(5)

    var body: some View {
        Group {
            if let text {
                Button(action: onDismiss) {
                    Text(text)
                        .kretaFont(KretaType.small)
                        .foregroundStyle(Palette.text)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.surfaceHigh, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.pressable)
                .transition(.opacity)
                .task(id: text) {
                    try? await Task.sleep(for: Self.visibleFor)
                    guard !Task.isCancelled else { return }
                    onDismiss()
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: text)
    }
}
