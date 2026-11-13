import Foundation
import KretaKit
import Observation
import os

/// What the screens observe. All network work is delegated to
/// `SyncCoordinator`, which the background task uses as well.
@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable {
        case loading
        case signedOut
        case signedIn(Account)
    }

    private(set) var phase: Phase = .loading
    private(set) var snapshot: TimetableSnapshot?
    private(set) var isSyncing = false
    /// The stored session no longer works; the timetable shown is the last one saved.
    private(set) var needsSignIn = false
    /// Set while KRÉTA's login page is open.
    var loginAttempt: LoginAttempt?
    private(set) var isSigningIn = false
    /// A short notice for the user; the toast dismisses it.
    private(set) var message: String?

    private let coordinator = SyncCoordinator.shared
    private let auth = AuthService()
    private let logger = Logger(subsystem: "hu.kretaora", category: "model")
    private var isDemo = false

    var account: Account? {
        if case .signedIn(let account) = phase { return account }
        return nil
    }

    /// Reads the stored session and the cached timetable, then refreshes.
    func start() async {
        guard phase == .loading else { return }
        if startDemoIfAsked() { return }
        do {
            guard let session = try coordinator.sessions.load() else {
                phase = .signedOut
                return
            }
            let stored = coordinator.snapshots.load()
            snapshot = stored?.accountID == session.account.id ? stored : nil
            phase = .signedIn(session.account)
            if coordinator.needsLogin {
                needsSignIn = true
                message = L10n.errorSessionExpired
            } else {
                await refresh()
            }
        } catch {
            logger.error("Could not read the stored session: \(error.localizedDescription)")
            phase = .signedOut
        }
        LiveLessonController.shared.update(snapshot: snapshot)
    }

    /// Opens KRÉTA's login page. The school is picked there, so nothing is typed here.
    func startLogin(institution: String? = nil) {
        do {
            loginAttempt = try LoginAttempt(institution: institution)
            message = nil
        } catch {
            message = (error as? KretaError)?.errorDescription ?? L10n.errorUnexpected
        }
    }

    /// Starts a new login for the same school after the session expired.
    func signInAgain() {
        startLogin(institution: account?.institutionCode)
    }

    /// Called with the intercepted OAuth redirect.
    func completeLogin(redirect: URL) async {
        guard let attempt = loginAttempt else { return }
        loginAttempt = nil
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            let session = try await auth.completeLogin(attempt: attempt, redirect: redirect)
            try coordinator.signIn(session)
            if snapshot?.accountID != session.account.id { snapshot = nil }
            needsSignIn = false
            message = nil
            phase = .signedIn(session.account)
            await Notifier.requestAuthorization()
            await refresh()
        } catch {
            message = text(for: error)
        }
    }

    /// Syncs unless a sync is already running or the session needs a new login.
    func refresh() async {
        guard account != nil, !isSyncing, !needsSignIn, !isDemo else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let result = try await coordinator.sync()
            snapshot = result.snapshot
            message = nil
        } catch KretaError.sessionExpired {
            // The cached timetable stays visible; only the session is gone.
            needsSignIn = true
            message = L10n.errorSessionExpired
        } catch KretaError.notLoggedIn {
            snapshot = nil
            phase = .signedOut
        } catch {
            message = text(for: error)
        }
        LiveLessonController.shared.update(snapshot: snapshot)
    }

    func signOut() async {
        if !isDemo {
            do {
                try await coordinator.signOut()
            } catch {
                logger.error("Sign out did not clean up completely: \(error.localizedDescription)")
            }
        }
        snapshot = nil
        needsSignIn = false
        message = nil
        phase = .signedOut
        LiveLessonController.shared.update(snapshot: nil)
    }

    func dismissMessage() {
        message = nil
    }

    private func text(for error: Error) -> String {
        if let kreta = error as? KretaError, let text = kreta.errorDescription { return text }
        if error is URLError { return L10n.errorOffline }
        return L10n.errorUnexpected
    }

    /// Debug builds can show every screen without an account.
    private func startDemoIfAsked() -> Bool {
        if LaunchOptions.showsLanding {
            phase = .signedOut
            return true
        }
        guard LaunchOptions.usesDemoData else { return false }
        isDemo = true
        snapshot = DemoTimetable.snapshot()
        phase = .signedIn(DemoTimetable.account)
        return true
    }
}
