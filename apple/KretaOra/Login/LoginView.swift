import KretaKit
import SwiftUI

/// The first screen: one optional field and one button. The password is only
/// ever typed on KRÉTA's own page inside the sheet.
struct LoginView: View {
    @Environment(AppModel.self) private var model
    @State private var institution = ""
    @State private var attempt: LoginAttempt?
    @State private var isCompleting = false
    @State private var fieldError: String?

    var body: some View {
        ZStack {
            LinearGradient(colors: [.board, .boardDeep], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 24)

                Text("KRÉTA ÓRAREND")
                    .font(.eyebrow)
                    .tracking(2)
                    .foregroundStyle(.chalkYellow)
                Text("Mindig tudd,\nmi a következő óra.")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(.chalk)
                    .padding(.top, 8)
                Text("Widget a kezdőképernyőn és az órádon, értesítés, ha elmarad egy óra vagy helyettesítés van.")
                    .font(.body)
                    .foregroundStyle(.chalkDim)
                    .padding(.top, 12)

                Spacer(minLength: 32)

                institutionField
                signInButton
                    .padding(.top, 14)

                if let message = fieldError ?? model.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.chalkRed)
                        .padding(.top, 10)
                }

                Text("Nem hivatalos alkalmazás. A jelszavadat a KRÉTA saját oldalán adod meg, az app nem látja és nem tárolja.")
                    .font(.caption)
                    .foregroundStyle(.chalkDim)
                    .padding(.top, 18)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .sheet(item: $attempt) { attempt in
            LoginSheet(attempt: attempt) { redirect in
                self.attempt = nil
                isCompleting = true
                Task {
                    await model.completeLogin(attempt: attempt, redirect: redirect)
                    isCompleting = false
                }
            }
        }
    }

    private var institutionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Intézménykód (nem kötelező)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.chalkDim)
            TextField("", text: $institution, prompt: Text("pl. klik012345678").foregroundStyle(.chalkDim))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(.go)
                .onSubmit(startLogin)
                .foregroundStyle(.chalk)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(.chalk.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.chalk.opacity(0.22)))
        }
    }

    private var signInButton: some View {
        Button(action: startLogin) {
            HStack {
                if isCompleting {
                    ProgressView().tint(Color.board)
                } else {
                    Text("Bejelentkezés a KRÉTA-val")
                    Image(systemName: "arrow.right")
                }
            }
            .font(.headline)
            .foregroundStyle(.board)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(.chalkYellow, in: RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isCompleting)
    }

    private func startLogin() {
        model.dismissError()
        do {
            attempt = try LoginAttempt(institution: institution)
            fieldError = nil
        } catch {
            fieldError = "Az intézménykód csak betűt, számot és kötőjelet tartalmazhat."
        }
    }
}

/// The hosted KRÉTA login with a way out.
private struct LoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    let attempt: LoginAttempt
    let onRedirect: (URL) -> Void

    var body: some View {
        NavigationStack {
            LoginWebView(url: attempt.url, onRedirect: onRedirect)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("KRÉTA bejelentkezés")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Mégse") { dismiss() }
                    }
                }
        }
    }
}
