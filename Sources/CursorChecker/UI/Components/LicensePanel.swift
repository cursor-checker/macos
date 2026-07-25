import SwiftUI

/// Scrollable license text shown from the About footer.
struct LicensePanel: View {
    let text: String
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.licenseTitle)
                    .font(.headline)
                Spacer()
                Button(L10n.commonClose, action: onClose)
            }
            .padding()

            Divider()

            ScrollView {
                Text(text)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
