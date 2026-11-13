import SwiftUI
import UserNotifications

@main
struct KretaOraApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    @MainActor
    init() {
        UNUserNotificationCenter.current().delegate = ForegroundNotificationPresenter.shared
        WatchLink.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Palette.text)
                .task { await model.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await model.refresh() }
            case .background:
                BackgroundRefresh.schedule()
            default:
                break
            }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.taskID)) {
            await BackgroundRefresh.run()
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack {
            Palette.background.ignoresSafeArea()
            switch model.phase {
            case .loading:
                EmptyView()
            case .signedOut:
                LandingView()
            case .signedIn:
                TimetableScreen()
            }
        }
        .fullScreenCover(item: $model.loginAttempt) { attempt in
            LoginWebScreen(
                attempt: attempt,
                onRedirect: { redirect in Task { await model.completeLogin(redirect: redirect) } },
                onCancel: { model.loginAttempt = nil }
            )
        }
        #if DEBUG
        .overlay {
            if LaunchOptions.showsWidgetGallery { WidgetGallery() }
        }
        #endif
    }
}
