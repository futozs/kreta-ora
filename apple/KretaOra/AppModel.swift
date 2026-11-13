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
    /// A message for the user when the last action failed.
    private(set) var errorMessage: String?
    /// Changes found since the app was opened, newest sync first.
    private(set) var recentChanges: [TimetableChange] = []

    private let coordinator = SyncCoordinator.shared
    private let auth = AuthService()
    private let logger = Logger(subsystem: "hu.kretaora", category: "model")

    var schedule: Schedule? { snapshot?.schedule }

    /// Reads the stored session and the cached timetable, then refreshes.
    func start() async {
        guard phase == .loading else { return }
        do {
            if let session = try coordinator.sessions.load() {
                snapshot = coordinator.snapshots.load()
                phase = .signedIn(session.account)
                await refresh()
            } else {
                phase = .signedOut
            }
        } catch {
            logger.error("Could not read the stored session: \(error.localizedDescription)")
            phase = .signedOut
        }
    }

    /// Called by the login web view once KRÉTA redirects back.
    func completeLogin(attempt: LoginAttempt, redirect: URL) async {
        do {
            let session = try await auth.completeLogin(attempt: attempt, redirect: redirect)
            try coordinator.signIn(session)
            Notifier.clearSessionExpired()
            errorMessage = nil
            recentChanges = []
            phase = .signedIn(session.account)
            await Notifier.requestAuthorization()
            await refresh()
        } catch {
            errorMessage = message(for: error)
        }
    }

    func refresh() async {
        guard case .signedIn = phase, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let result = try await coordinator.sync()
            snapshot = result.snapshot
            recentChanges = (result.changes + recentChanges).uniqued()
            errorMessage = nil
        } catch KretaError.sessionExpired {
            // The cached timetable stays visible; only the session is gone.
            errorMessage = KretaError.sessionExpired.errorDescription
        } catch {
            errorMessage = message(for: error)
        }
    }

    func signOut() async {
        do {
            try await coordinator.signOut()
        } catch {
            logger.error("Sign out did not clean up completely: \(error.localizedDescription)")
        }
        snapshot = nil
        recentChanges = []
        errorMessage = nil
        phase = .signedOut
    }

    func dismissError() {
        errorMessage = nil
    }

    private func message(for error: Error) -> String {
        if let kreta = error as? KretaError, let text = kreta.errorDescription { return text }
        if error is URLError { return "Nincs kapcsolat a KRÉTA szerverrel. Az utoljára letöltött órarendet látod." }
        return "Váratlan hiba történt. Próbáld újra."
    }
}

private extension Array where Element == TimetableChange {
    /// Keeps the first occurrence of each change.
    func uniqued() -> [TimetableChange] {
        var seen = Set<String>()
        return filter { seen.insert("\($0.id)@\($0.lesson.start.timeIntervalSince1970)").inserted }
    }
}
