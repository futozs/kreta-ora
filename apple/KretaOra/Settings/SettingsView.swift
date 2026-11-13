import KretaKit
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let account: Account
    @State private var notificationsAllowed = true
    @State private var confirmsSignOut = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Fiók") {
                    LabeledContent("Név", value: account.displayName)
                    LabeledContent("Intézmény", value: account.institutionCode)
                    if let syncedAt = model.snapshot?.syncedAt {
                        LabeledContent("Utolsó frissítés") {
                            Text(syncedAt, style: .relative)
                        }
                    }
                }

                Section {
                    if notificationsAllowed {
                        Label("Az értesítések be vannak kapcsolva", systemImage: "bell.badge.fill")
                    } else {
                        Button {
                            if let settings = URL(string: UIApplication.openSettingsURLString) {
                                openURL(settings)
                            }
                        } label: {
                            Label("Értesítések engedélyezése a Beállításokban", systemImage: "bell.slash")
                        }
                    }
                } header: {
                    Text("Értesítések")
                } footer: {
                    Text("Az app a háttérben is ellenőrzi az órarendet, de azt az iOS dönti el, milyen gyakran engedi futni. Egy változásról ezért akár késve is értesülhetsz. Megnyitáskor mindig azonnal frissít.")
                }

                Section {
                    Button("Kijelentkezés", role: .destructive) {
                        confirmsSignOut = true
                    }
                } footer: {
                    Text("Nem hivatalos alkalmazás, nem áll kapcsolatban a KRÉTA üzemeltetőjével. Az adataid a telefonodon maradnak: az app csak a KRÉTA szervereivel kommunikál.")
                }
            }
            .navigationTitle("Beállítások")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kész") { dismiss() }
                }
            }
            .confirmationDialog("Biztosan kijelentkezel?", isPresented: $confirmsSignOut, titleVisibility: .visible) {
                Button("Kijelentkezés", role: .destructive) {
                    Task {
                        await model.signOut()
                        dismiss()
                    }
                }
            } message: {
                Text("A letöltött órarend törlődik erről a telefonról és az óráról.")
            }
            .task {
                notificationsAllowed = await Notifier.isAuthorized()
            }
        }
    }
}
