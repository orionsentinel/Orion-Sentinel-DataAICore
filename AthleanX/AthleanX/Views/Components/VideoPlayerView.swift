import SwiftUI
import WebKit
import AVKit

struct VideoPlayerView: View {
    let videoURL: String?
    let thumbnailURL: String
    @State private var isPlaying = false

    var body: some View {
        ZStack {
            if isPlaying, let urlString = videoURL, let url = URL(string: urlString) {
                if urlString.contains("youtube") || urlString.contains("youtu.be") || urlString.contains("vimeo") {
                    WebVideoPlayer(url: url)
                } else {
                    NativeVideoPlayer(url: url)
                }
            } else {
                thumbnailOverlay
            }
        }
        .cornerRadius(0)
        .clipped()
    }

    private var thumbnailOverlay: some View {
        ZStack {
            AsyncImage(url: URL(string: thumbnailURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Constants.Colors.cardBackground
            }
            .clipped()

            Color.black.opacity(0.3)

            Button {
                isPlaying = true
            } label: {
                Circle()
                    .fill(.white.opacity(0.9))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.title3)
                            .foregroundColor(.black)
                            .offset(x: 2)
                    )
            }
        }
    }
}

struct WebVideoPlayer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .black
        webView.isOpaque = false
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let embedURL = buildEmbedURL(from: url)
        let html = """
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        body { margin: 0; background: black; }
        iframe { width: 100%; height: 100vh; border: none; }
        </style>
        </head>
        <body>
        <iframe src="\(embedURL)" allowfullscreen></iframe>
        </body>
        </html>
        """
        uiView.loadHTMLString(html, baseURL: nil)
    }

    private func buildEmbedURL(from url: URL) -> String {
        let urlString = url.absoluteString
        if urlString.contains("youtube.com/watch") {
            let videoId = URLComponents(string: urlString)?.queryItems?.first(where: { $0.name == "v" })?.value ?? ""
            return "https://www.youtube-nocookie.com/embed/\(videoId)?playsinline=1&autoplay=1"
        }
        if urlString.contains("youtu.be/") {
            let videoId = url.lastPathComponent
            return "https://www.youtube-nocookie.com/embed/\(videoId)?playsinline=1&autoplay=1"
        }
        if urlString.contains("vimeo.com/") {
            let videoId = url.lastPathComponent
            return "https://player.vimeo.com/video/\(videoId)?autoplay=1"
        }
        return urlString
    }
}

struct NativeVideoPlayer: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player = AVPlayer(url: url)
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        player.play()
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}
