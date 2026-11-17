import SwiftUI

/// The save/update offer after a login or a completed HTTP auth. It is an
/// overlay in the browser's own hierarchy, not a second sheet: a sheet requested
/// while the auth sheet was tearing down existed but never became interactive.
struct CredentialSaveOverlay: View {
    let pending: PendingCredential
    @EnvironmentObject var model: BrowserModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.16).ignoresSafeArea()
            card
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("credential.save")
    }

    private var card: some View {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Save password?")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Theme.panelInk)
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

/// The browser's own HTTP authentication prompt. It is an overlay in the
/// browser's hierarchy, not a sheet: a dismissed sheet's presentation container
/// can still swallow the next tap, and the save card that follows must be
/// tappable on the first try. The challenge completion lives in the model, so
/// Cancel answers the server instead of leaving a page spinning, and nothing
/// here can hand the user back the system's blank challenge.
struct HTTPAuthCard: View {
    let auth: PendingHTTPAuth
    @EnvironmentObject var model: BrowserModel

    @State private var username: String
    @State private var password = ""

    init(auth: PendingHTTPAuth) {
        self.auth = auth
        _username = State(initialValue: auth.username)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.16).ignoresSafeArea()
            card.offset(y: -48)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("auth.card")
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(auth.host)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.panelInk)
                Spacer(minLength: 8)
                Button("Cancel") { model.cancelHTTPAuth() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.panelMuted)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("auth.cancel")
            }

            Text(auth.realm.isEmpty
                 ? "The server requires a username and password."
                 : "The server's “\(auth.realm)” area requires a username and password.")
                .font(.system(size: 12))
                .foregroundColor(Theme.panelMuted)
                .fixedSize(horizontal: false, vertical: true)

            if auth.failed {
                Text("That username and password were not accepted.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.panelInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            AuthField(placeholder: "Username", text: $username, keyboard: .emailAddress)
                .frame(height: 40)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
            AuthField(placeholder: "Password", text: $password, secure: true)
                .frame(height: 40)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))

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
                    // A disabled white plate keeps the desktop's light ink: fading
                    // the plate made the label grey-on-grey in dark, which the
                    // captures showed.
                    .foregroundColor(incomplete ? Theme.fieldPlaceholder : Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("auth.signIn")
            .disabled(incomplete)
        }
        .padding(20)
        .frame(maxWidth: 340)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.rowBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.18), radius: 24, y: 12)
        .padding(24)
        .accessibilityElement(children: .contain)
    }

}

/// A credential field the system's Password AutoFill leaves alone. A native
/// username + secure pair is saved by iOS's own “Save Password?” sheet when the
/// fields leave the hierarchy, and that sheet is a modal window above the app:
/// it swallowed every tap on the browser's save card (run `44131988911`).
/// `.oneTimeCode` is the documented way to keep a secure field out of the
/// AutoFill login flow, and both fields carry it so no pair is recognised.
private struct AuthField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var secure = false
    var keyboard: UIKeyboardType = .default

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.textContentType = .oneTimeCode
        field.isSecureTextEntry = secure
        field.keyboardType = keyboard
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.textColor = UIColor(Theme.plateInk)
        field.font = .systemFont(ofSize: 15)
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor(Theme.fieldPlaceholder)]
        )
        field.accessibilityLabel = placeholder
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.text = $text
        if field.text != text { field.text = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) { self.text = text }

        @objc func changed(_ field: UITextField) {
            text.wrappedValue = field.text ?? ""
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            field.resignFirstResponder()
            return true
        }
    }
}
