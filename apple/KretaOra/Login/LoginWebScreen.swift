import KretaKit
import SwiftUI

/// KRÉTA's hosted login page. The password never passes through the app's own UI.
struct LoginWebScreen: View {
    let attempt: LoginAttempt
    let onRedirect: (URL) -> Void
    let onCancel: () -> Void

    @State private var progress: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(L10n.loginWebTitle)
                        .kretaFont(KretaType.headline)
                        .foregroundStyle(Palette.text)
                    Text(L10n.loginWebHost)
                        .kretaFont(KretaType.small)
                        .foregroundStyle(Palette.textDim)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.text)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.pressable)
                .glassEffect(.regular.interactive(), in: Circle())
                .accessibilityLabel(L10n.loginCancel)
            }
            .padding(.leading, 20)
            .padding(.trailing, 14)
            .padding(.top, 6)
            .padding(.bottom, 10)

            LoginWebView(url: attempt.url, onRedirect: onRedirect, onProgress: { progress = $0 })
                .overlay(alignment: .top) {
                    ProgressView(value: progress)
                        .progressViewStyle(PillProgressStyle(height: 3, fill: Palette.text, track: Palette.surfaceHigh))
                        .opacity(progress < 1 ? 1 : 0)
                        .animation(.easeOut(duration: 0.25), value: progress < 1)
                }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous))
                .ignoresSafeArea(edges: .bottom)
        }
        .background(Palette.background.ignoresSafeArea())
    }
}
