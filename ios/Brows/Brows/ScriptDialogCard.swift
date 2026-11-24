import SwiftUI

/// The browser's own JavaScript dialog. It is an overlay in the browser's
/// hierarchy, like every other browser-owned surface: a system alert here would
/// be the app borrowing chrome it already draws itself, and it would lose the
/// app's ink and plates.
struct ScriptDialogCard: View {
    let dialog: PendingScriptDialog
    @EnvironmentObject var model: BrowserModel

    @State private var text: String

    init(dialog: PendingScriptDialog) {
        self.dialog = dialog
        _text = State(initialValue: dialog.defaultText)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.16).ignoresSafeArea()
            card.offset(y: -48)
        }
        .onAppear { model.refreshPanelBackdrop() }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dialog.card")
    }

    private var card: some View {
        ZStack {
            // A material pane, not a fill: the desktop alert is a glass plate and the
            // page behind it is still the backdrop. A plain fill reads as a slab and
            // an empty glassEffect renders nothing, letting the article's lines
            // through unblurred (captures notice-light, dialog-light, linknotice-light).
            GlassPane(cornerRadius: 18, plate: true, backdrop: model.panelBackdrop)
        VStack(alignment: .leading, spacing: 14) {
            // The page's host, in the same muted line the credential card uses, so
            // a dialog is always attributable to the site that raised it.
            Text(dialog.host.isEmpty ? "This page" : dialog.host)
                .scaledFont(12, .semibold)
                .foregroundColor(Theme.panelMuted)

            Text(dialog.message.isEmpty ? "This page has a message." : dialog.message)
                .scaledFont(15)
                .foregroundColor(Theme.panelInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("dialog.message")

            if dialog.kind == .prompt {
                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .foregroundColor(Theme.plateInk)
                    .padding(.horizontal, 10)
                    .frame(height: 40)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.rowFill))
                    .accessibilityLabel("dialog.field")
                    .accessibilityIdentifier("dialog.field")
            }

            Button {
                model.finishScriptDialog(dialog.kind == .prompt ? .text(text) : .ok)
            } label: {
                Text("OK")
                    .scaledFont(14, .semibold)
                    .foregroundColor(Theme.panelInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.rowFill))
            .accessibilityIdentifier("dialog.ok")

            // An alert has nothing to cancel: dismissing it is its only answer.
            if dialog.kind != .alert {
                Button("Cancel") { model.finishScriptDialog(.cancel) }
                    .scaledFont(13, .semibold)
                    .foregroundColor(Theme.panelMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("dialog.cancel")
            }
        }
        .padding(20)
        }
        .frame(maxWidth: 340)
        // Hug the content: the full-screen scrim in the same ZStack otherwise hands
        // the glass a full-height proposal, and the dialog filled the screen with
        // its text centred (capture dialog-dark, run 44656125222).
        .fixedSize(horizontal: false, vertical: true)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.rowBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.18), radius: 24, y: 12)
        .padding(24)
        .accessibilityElement(children: .contain)
    }
}
