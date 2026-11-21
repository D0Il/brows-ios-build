import UIKit
import SwiftUI

/// Passwords: the desktop panel's operations, on the phone. Secrets stay in the
/// Keychain; export is an explicit action the user starts.
struct PasswordsSheet: View {
    @EnvironmentObject var model: BrowserModel
    @Environment(\.dismiss) private var dismiss

    @State private var host = ""
    @State private var username = ""
    @State private var secret = ""
    @State private var revealed: Set<UUID> = []
    @State private var showingImport = false
    @State private var importText = ""
    @State private var status: String?

    var body: some View {
        NavigationView {
            ZStack {
                GlassPane(cornerRadius: 0).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        addForm
                        if let status {
                            Text(status)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.panelMuted)
                        }
                        list
                        actions
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Passwords")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingImport) {
                importSheet
            }
        }
        .navigationViewStyle(.stack)
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ADD PASSWORD")
                .font(.system(size: 10, weight: .semibold))
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
                    .font(.system(size: 14, weight: .semibold))
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
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(Theme.panelMuted)

            if let error = model.credentialError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.panelMuted)
            }

            if model.credentials.isEmpty {
                Text("No passwords saved.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.panelMuted)
            }

            ForEach(model.credentials) { credential in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(credential.host)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.panelInk)
                        Spacer(minLength: 8)
                        Text(credential.username)
                            .font(.system(size: 11))
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
                                .font(.system(size: 11, design: .monospaced))
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
                            model.deleteCredential(credential)
                        }
                    }
                    .font(.system(size: 11, weight: .semibold))
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
                    .font(.system(size: 13, weight: .semibold))
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
                    .font(.system(size: 13, weight: .semibold))
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
                GlassPane(cornerRadius: 0).ignoresSafeArea()
                VStack(spacing: 10) {
                    Text("Paste the JSON exported from Brows' Passwords panel.")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.panelMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextEditor(text: $importText)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.rowFill))

                    Button {
                        let count = model.importCredentials(from: importText)
                        status = count > 0 ? "Imported \(count) passwords." : "Nothing to import."
                        importText = ""
                        showingImport = false
                    } label: {
                        Text("Import")
                            .font(.system(size: 14, weight: .semibold))
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
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.plateBase))
    }

    private func secureField(_ label: String, text: Binding<String>) -> some View {
        SecureField("", text: text, prompt: Text(label).foregroundColor(Theme.fieldPlaceholder))
            .textFieldStyle(.plain)
            .accessibilityLabel(label)
            .foregroundColor(Theme.panelInk)
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.plateBase))
    }
}
