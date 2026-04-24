import SwiftUI
import WebKit

struct CommunityView: View {
    @State private var selectedSegment = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.athleanDark.ignoresSafeArea()
                VStack(spacing: 0) {
                    segmentControl
                    if selectedSegment == 0 {
                        ForumWebView()
                    } else {
                        challengesView
                    }
                }
            }
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var segmentControl: some View {
        Picker("", selection: $selectedSegment) {
            Text("Forum").tag(0)
            Text("Challenges").tag(1)
        }
        .pickerStyle(.segmented)
        .padding()
    }

    private var challengesView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("ACTIVE CHALLENGES")
                    .font(.caption.bold())
                    .foregroundColor(Constants.Colors.textSecondary)
                    .tracking(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                ForEach(sampleChallenges, id: \.title) { challenge in
                    ChallengeCard(challenge: challenge)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    private var sampleChallenges: [(title: String, description: String, participants: Int, daysLeft: Int)] {
        [
            ("30-Day Ab Challenge", "Complete an ab workout every day for 30 days", 1247, 12),
            ("Pull-up Progress", "Add 5 pull-ups to your max in 4 weeks", 892, 21),
            ("Hydration Challenge", "Drink 1 gallon of water daily for 2 weeks", 2103, 5)
        ]
    }
}

struct ForumWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = UIColor(Constants.Colors.athleanDark)
        webView.isOpaque = false
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let accessToken = try? KeychainManager.shared.retrieve(for: Constants.Keychain.accessTokenKey),
              let url = URL(string: "\(Constants.API.portalBaseURL)/community?token=\(accessToken)") else {
            if let url = URL(string: "\(Constants.API.portalBaseURL)/community") {
                uiView.load(URLRequest(url: url))
            }
            return
        }
        uiView.load(URLRequest(url: url))
    }
}

struct ChallengeCard: View {
    let challenge: (title: String, description: String, participants: Int, daysLeft: Int)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(challenge.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                Text("\(challenge.daysLeft)d left")
                    .font(.caption.bold())
                    .foregroundColor(challenge.daysLeft <= 7 ? .orange : Constants.Colors.textSecondary)
            }
            Text(challenge.description)
                .font(.caption)
                .foregroundColor(Constants.Colors.textSecondary)
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(Constants.Colors.athleanRed)
                    .font(.caption)
                Text("\(challenge.participants.formatted()) participants")
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)
                Spacer()
                Button("Join") {}
                    .font(.caption.bold())
                    .foregroundColor(Constants.Colors.athleanRed)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Constants.Colors.athleanRed, lineWidth: 1)
                    )
            }
        }
        .cardStyle()
    }
}
