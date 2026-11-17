import SwiftUI

/// The save/update offer after a login or a completed HTTP auth. It is an owned
/// sheet rather than a system alert: the alert's presented-binding tore down the
/// offer around the button action, and a second finished navigation could replace
/// the alert before the tap was delivered.
struct CredentialSaveSheet: View {
    let pending: PendingCredential
    @EnvironmentObject var model: BrowserModel

    var body: some View {
        NavigationView {
            ZStack {
                Theme.surface.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pending.username.isEmpty ? pending.host : pending.username)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Theme.panelInk)
                            Text(pending.host)
                                .font(.system(size: 12))
                                .foregroundColor(Theme.panelMuted)
                        }

                        Text(message)
                            .font(.system(size: 13))
                            .foregroundColor(Theme.panelMuted)
                            .fixedSize(horizontal: false, vertical: true)

                        if pending.isSecondAccount {
                            action("Save new account", id: "save.new") {
                                model.confirmPendingCredential(pending)
                            }
                            action("Update \(pending.existingUsername ?? "saved password")", id: "save.update") {
                                model.updatePendingCredential(pending)
                            }
                        } else if pending.existingID != nil {
                            action("Update password", id: "save.update") {
                                model.updatePendingCredential(pending)
                            }
                        } else {
                            action("Save", id: "save.new") {
                                model.confirmPendingCredential(pending)
                            }
                        }

                        Button("Not now") { model.discardPendingCredential() }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.panelMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("save.notNow")
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Save password?")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }

    private var message: String {
        if pending.isSecondAccount, let existing = pending.existingUsername {
            return "A password for this site is already saved as \(existing). Save \(pending.username) as another account, or replace the saved one?"
        }
        if pending.existingID != nil {
            return "Update the saved password for \(pending.username) on \(pending.host)?"
        }
        return "Save the password for \(pending.username) on \(pending.host)? The secret goes to the Keychain, never to app storage."
    }

    private func action(_ title: String, id: String, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

/// The browser's own HTTP authentication prompt. The challenge completion lives
/// in the model, so Cancel answers the server instead of leaving a page spinning,
/// and nothing here can hand the user back the system's blank challenge.
struct HTTPAuthSheet: View {
    let auth: PendingHTTPAuth
    @EnvironmentObject var model: BrowserModel

    @State private var username: String
    @State private var password = ""

    init(auth: PendingHTTPAuth) {
        self.auth = auth
        _username = State(initialValue: auth.username)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Theme.surface.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(auth.host)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Theme.panelInk)
                            Text(auth.realm.isEmpty
                                 ? "The server requires a username and password."
                                 : "The server's “\(auth.realm)” area requires a username and password.")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.panelMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if auth.failed {
                            Text("That username and password were not accepted.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.panelInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        field("Username", text: $username, keyboard: .emailAddress)
                        secureField("Password", text: $password)

                        if auth.isPrivate {
                            Text("Private tab: these credentials are used for this session and are not saved.")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.panelMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        let incomplete = username.isEmpty || password.isEmpty
                        Button {
                            model.submitHTTPAuth(username: username, password: password)
                        } label: {
                            Text("Sign in")
                                .font(.system(size: 14, weight: .semibold))
                                // A disabled white plate keeps the desktop's light ink:
                                // fading the whole plate made the label grey-on-grey in
                                // dark, which the captures showed.
                                .foregroundColor(incomplete ? Theme.fieldPlaceholder : Theme.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("auth.signIn")
                        .disabled(incomplete)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Sign in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { model.cancelHTTPAuth() }
                        .accessibilityIdentifier("auth.cancel")
                }
            }
        }
        .navigationViewStyle(.stack)
        .onDisappear { model.cancelHTTPAuth() }
    }

    private func field(_ label: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        TextField("", text: text, prompt: Text(label).foregroundColor(Theme.fieldPlaceholder))
            .textFieldStyle(.plain)
            .accessibilityLabel(label)
            .keyboardType(keyboard)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .foregroundColor(Theme.plateInk)
            .padding(.horizontal, 10)
            .frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
    }

    private func secureField(_ label: String, text: Binding<String>) -> some View {
        SecureField("", text: text, prompt: Text(label).foregroundColor(Theme.fieldPlaceholder))
            .textFieldStyle(.plain)
            .accessibilityLabel(label)
            .foregroundColor(Theme.plateInk)
            .padding(.horizontal, 10)
            .frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
    }
}
