import SwiftUI
import UserNotifications

@main
struct KretaOraApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UNUserNotificationCenter.current().delegate = ForegroundNotificationPresenter.shared
        WatchLink.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Color.board)
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
        switch model.phase {
        case .loading:
            ZStack {
                Color.board.ignoresSafeArea()
                ProgressView().tint(Color.chalk)
            }
        case .signedOut:
            LoginView()
        case .signedIn(let account):
            TimetableView(account: account)
        }
    }
}
