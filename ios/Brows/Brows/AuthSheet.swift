import SwiftUI

/// The save/update offer after a login or a completed HTTP auth. It is an
/// overlay in the browser's own hierarchy, not a second sheet: a sheet requested
/// while the auth sheet was tearing down existed but never became interactive.
struct CredentialSaveOverlay: View {
    let pending: PendingCredential
    var embedded = false
    @EnvironmentObject var model: BrowserModel

    var body: some View {
        if embedded {
            card
        } else {
            ZStack {
                Color.black.opacity(0.16).ignoresSafeArea()
                card
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("credential.save")
        }
    }

    private var card: some View {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    // Inside the auth sheet the navigation bar already reads
                    // "Save password?"; repeating it would stack two headings.
                    if !embedded {
                        Text("Save password?")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Theme.panelInk)
                    }
                    Text(pending.username.isEmpty ? pending.host : "\(pending.username) on \(pending.host)")
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
                    .padding(.vertical, 8)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("save.notNow")
            }
            .padding(20)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.rowBorder, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.18), radius: 24, y: 12)
            .padding(24)
            .accessibilityElement(children: .contain)
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

                if let pending = inlineOffer {
                    ScrollView {
                        CredentialSaveOverlay(pending: pending, embedded: true)
                    }
                } else {
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
            }
            .navigationTitle(inlineOffer == nil ? "Sign in" : "Save password?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { model.cancelHTTPAuth() }
                        .accessibilityIdentifier("auth.cancel")
                }
            }
        }
        .navigationViewStyle(.stack)
        .onDisappear {
            model.cancelHTTPAuth()
            model.httpAuthSheetDidDisappear()
        }
    }

    /// The card belongs to a challenge this sheet has already answered. An offer
    /// left over from a form login must not take over the sheet and hide the form.
    private var inlineOffer: PendingCredential? {
        guard auth.completed, let pending = model.pendingCredential else { return nil }
        return pending
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
