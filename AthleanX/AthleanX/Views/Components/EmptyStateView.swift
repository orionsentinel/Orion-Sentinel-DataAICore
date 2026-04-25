import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(Constants.Colors.textSecondary.opacity(0.5))

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(Constants.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                }
                .athleanButtonStyle()
                .frame(maxWidth: 220)
            }
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

struct ErrorStateView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        EmptyStateView(
            icon: "exclamationmark.triangle.fill",
            title: "Something went wrong",
            message: message,
            actionTitle: "Try Again",
            action: retryAction
        )
    }
}

struct LoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Constants.Colors.athleanRed)
                .scaleEffect(1.4)
            Text(message)
                .font(.subheadline)
                .foregroundColor(Constants.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
