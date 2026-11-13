import KretaKit
import SwiftUI

@main
struct KretaOraWatchApp: App {
    @State private var model = WatchModel.shared

    @MainActor
    init() {
        WatchModel.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(model)
        }
    }
}

struct WatchRootView: View {
    @Environment(WatchModel.self) private var model

    var body: some View {
        if let snapshot = model.snapshot {
            WatchDayPager(snapshot: snapshot)
        } else {
            WatchSignedOut()
        }
    }
}

/// The watch holds no account of its own: the phone sends the timetable.
private struct WatchSignedOut: View {
    var body: some View {
        NavigationStack { content }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer(minLength: 0)
            Text(L10n.watchSignedOut)
                .kretaFont(KretaType.headline.size(20))
                .foregroundStyle(Palette.text)
            Text(L10n.watchSignedOutBody)
                .kretaFont(KretaType.small.size(13))
                .foregroundStyle(Palette.textDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.horizontal, 6)
        .containerBackground(Palette.background, for: .navigation)
    }
}
