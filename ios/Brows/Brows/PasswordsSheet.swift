import UIKit
import SwiftUI

/// Passwords: the desktop panel's operations, on the phone. Secrets stay in the
/// Keychain; export is an explicit action the user starts.
struct PasswordsSheet: View {
    @EnvironmentObject var model: BrowserModel
    @Environment(\.panelDismiss) private var dismiss

    @State private var host = ""
    @State private var username = ""
    @State private var secret = ""
    @State private var revealed: Set<UUID> = []
    @State private var showingImport = false
    @State private var importText = ""
    @State private var status: String?
    @State private var pendingDelete: Credential?
    @State private var confirmingDelete = false

    var body: some View {
        VStack(spacing: 0) {
            PanelBar(title: "Passwords") {
                Button("Done") { dismiss() }
            }
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        addForm
                        if let status {
                            Text(status)
                                .scaledFont(11)
                                .foregroundColor(Theme.panelMuted)
                        }
                        list
                        actions
                    }
                    .padding(16)
                }
            }
            .sheet(isPresented: $showingImport) {
                importSheet
            }
        }
        .confirmationDialog(
            "Delete this saved password?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let credential = pendingDelete { model.deleteCredential(credential) }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("It is removed from the Keychain. The site will ask you to sign in again.")
        }
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ADD PASSWORD")
                .scaledFont(10, .semibold)
                .tracking(1.2)
                .foregroundColor(Theme.panelMuted)

            field("Site", text: $host, keyboard: .URL)
            field("Username", text: $username, keyboard: .emailAddress)
            secureField("Password", text: $secret)

            Button {
                if model.addCredential(host: host, username: username, secret: secret) {
                    status = "Saved \(host) to the Keychain."
                    host = ""; username = ""; secret = ""
                } else {
                    status = "Need a site, a username and a password."
                }
            } label: {
                Text("Save")
                    .scaledFont(14, .semibold)
                    .foregroundColor(Theme.panelInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .panelButtonPlate()
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.rowFill))
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SAVED")
                .scaledFont(10, .semibold)
                .tracking(1.2)
                .foregroundColor(Theme.panelMuted)

            if let error = model.credentialError {
                Text(error)
                    .scaledFont(11)
                    .foregroundColor(Theme.panelMuted)
            }

            if model.credentials.isEmpty {
                Text("No passwords saved.")
                    .scaledFont(12)
                    .foregroundColor(Theme.panelMuted)
            }

            ForEach(model.credentials) { credential in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(credential.host)
                            .scaledFont(14, .medium)
                            .foregroundColor(Theme.panelInk)
                        Spacer(minLength: 8)
                        Text(credential.username)
                            .scaledFont(11)
                            .foregroundColor(Theme.panelMuted)
                            .lineLimit(1)
                    }

                    HStack(spacing: 14) {
                        Button(revealed.contains(credential.id) ? "Hide" : "Reveal") {
                            if revealed.contains(credential.id) {
                                revealed.remove(credential.id)
                            } else {
                                revealed.insert(credential.id)
                            }
                        }
                        if revealed.contains(credential.id) {
                            Text(model.secret(for: credential) ?? "—")
                                .scaledFont(11, design: .monospaced)
                                .foregroundColor(Theme.panelMuted)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Button("Fill") {
                            model.fillCredential(credential)
                            dismiss()
                        }
                        Button("Copy") {
                            if let value = model.secret(for: credential) {
                                UIPasteboard.general.string = value
                                status = "Password copied for \(credential.host)."
                            }
                        }
                        Button("Delete", role: .destructive) {
                            pendingDelete = credential
                            confirmingDelete = true
                        }
                    }
                    .scaledFont(11, .semibold)
                    .foregroundColor(Theme.panelMuted)
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.rowFill))
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                UIPasteboard.general.string = model.exportCredentials()
                status = "Exported \(model.credentials.count) entries to the clipboard as JSON."
            } label: {
                Text("Export")
                    .scaledFont(13, .semibold)
                    .foregroundColor(Theme.panelInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .panelButtonPlate()
            }
            .buttonStyle(.plain)

            Button {
                showingImport = true
            } label: {
                Text("Import")
                    .scaledFont(13, .semibold)
                    .foregroundColor(Theme.panelInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .panelButtonPlate()
            }
            .buttonStyle(.plain)
        }
    }

    private var importSheet: some View {
        NavigationView {
            ZStack {
                GlassPane(cornerRadius: 0, plate: true).ignoresSafeArea()
                VStack(spacing: 10) {
                    Text("Paste the JSON exported from Brows' Passwords panel.")
                        .scaledFont(12)
                        .foregroundColor(Theme.panelMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextEditor(text: $importText)
                        .scaledFont(12, design: .monospaced)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.rowFill))

                    Button {
                        let count = model.importCredentials(from: importText)
                        status = count > 0 ? "Imported \(count) passwords." : "Nothing to import."
                        importText = ""
                        showingImport = false
                    } label: {
                        Text("Import")
                            .scaledFont(14, .semibold)
                            .foregroundColor(Theme.panelInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.plateBase.opacity(0.9)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { showingImport = false }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func field(_ label: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        TextField("", text: text, prompt: Text(label).foregroundColor(Theme.fieldPlaceholder))
            .textFieldStyle(.plain)
            .accessibilityLabel(label)
            .keyboardType(keyboard)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .foregroundColor(Theme.panelInk)
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.rowFill))
    }

    private func secureField(_ label: String, text: Binding<String>) -> some View {
        SecureField("", text: text, prompt: Text(label).foregroundColor(Theme.fieldPlaceholder))
            .textFieldStyle(.plain)
            .accessibilityLabel(label)
            .foregroundColor(Theme.panelInk)
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.rowFill))
    }
}
