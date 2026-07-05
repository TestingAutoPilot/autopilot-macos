import SwiftUI

/// Shown when Accessibility permission is missing. The app is inert but honest
/// until the user grants it — nothing is faked.
struct PermissionBanner: View {
    let instructions: String
    let onRecheck: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility permission required").font(.headline)
                Text(instructions).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("Recheck", action: onRecheck)
        }
        .padding(12)
        .background(.orange.opacity(0.12))
    }
}
