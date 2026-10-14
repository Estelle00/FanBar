import SwiftUI

/// Keep the native macOS 12 enhancements without raising the app's Big Sur minimum.
@MainActor
extension View {
    @ViewBuilder
    func fanBarPrimaryButton() -> some View {
        if #available(macOS 12.0, *) {
            buttonStyle(.borderedProminent)
        } else {
            buttonStyle(DefaultButtonStyle())
        }
    }

    @ViewBuilder
    func fanBarSelectableText() -> some View {
        if #available(macOS 12.0, *) {
            textSelection(.enabled)
        } else {
            // Big Sur retains the explicit Copy ID and Export actions.
            self
        }
    }

    @ViewBuilder
    func fanBarInteractiveDismissDisabled(_ disabled: Bool) -> some View {
        if #available(macOS 12.0, *) {
            interactiveDismissDisabled(disabled)
        } else {
            // Upload credentials are persisted before sending, even if the sheet closes.
            self
        }
    }
}
