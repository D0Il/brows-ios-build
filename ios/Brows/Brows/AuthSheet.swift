import SwiftUI

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
