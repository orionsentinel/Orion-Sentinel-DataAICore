import SwiftUI

// MARK: - Root auth gate

struct OnboardingView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        if authViewModel.isCheckingSession {
            SplashView()
        } else {
            LoginView()
                .environmentObject(authViewModel)
        }
    }
}

// MARK: - Splash (shown while session check runs)

struct SplashView: View {
    @State private var boltScale: CGFloat = 0.6
    @State private var boltOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                AthleanLogoMark(size: 72)
                    .scaleEffect(boltScale)
                    .opacity(boltOpacity)
                Text("ATHLEAN-X")
                    .font(.system(size: 22, weight: .black, design: .default))
                    .foregroundColor(.white)
                    .tracking(6)
                    .opacity(boltOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                boltScale = 1.0
                boltOpacity = 1.0
            }
        }
    }
}

// MARK: - Login screen

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @FocusState private var focusedField: Field?
    @State private var showPassword = false

    enum Field { case email, password }

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            backgroundPattern

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)
                    logoSection
                    Spacer(minLength: 48)
                    formCard
                    Spacer(minLength: 32)
                    footerLinks
                    Spacer(minLength: 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)

            // Full-screen loading overlay
            if authViewModel.isLoading {
                loadingOverlay
            }
        }
    }

    // MARK: Subviews

    private var backgroundPattern: some View {
        VStack {
            Spacer()
            AthleanLogoMark(size: 340)
                .foregroundStyle(Color.white.opacity(0.025))
                .rotationEffect(.degrees(-15))
                .offset(x: 80, y: 40)
        }
        .ignoresSafeArea()
    }

    private var logoSection: some View {
        VStack(spacing: 12) {
            AthleanLogoMark(size: 64)
            VStack(spacing: 4) {
                Text("ATHLEAN-X")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.white)
                    .tracking(5)
                Text("Sign in to your account")
                    .font(.subheadline)
                    .foregroundColor(Color(white: 0.55))
            }
        }
    }

    private var formCard: some View {
        VStack(spacing: 20) {
            // Error banner
            if let error = authViewModel.errorMessage {
                errorBanner(error)
            }

            // Email
            inputField(
                label: "EMAIL",
                placeholder: "you@example.com",
                text: $authViewModel.email,
                keyboardType: .emailAddress,
                autocapitalization: .never,
                isSecure: false,
                showSecureToggle: false,
                showPassword: $showPassword
            )
            .focused($focusedField, equals: .email)
            .submitLabel(.next)
            .onSubmit { focusedField = .password }

            // Password
            inputField(
                label: "PASSWORD",
                placeholder: "••••••••",
                text: $authViewModel.password,
                keyboardType: .default,
                autocapitalization: .never,
                isSecure: !showPassword,
                showSecureToggle: true,
                showPassword: $showPassword
            )
            .focused($focusedField, equals: .password)
            .submitLabel(.go)
            .onSubmit { Task { await authViewModel.login() } }

            // Remember me
            HStack {
                Toggle(isOn: $authViewModel.rememberMe) {
                    Text("Remember me")
                        .font(.subheadline)
                        .foregroundColor(Color(white: 0.6))
                }
                .tint(Constants.Colors.athleanRed)
            }

            // Sign in button
            signInButton
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.09))
                .shadow(color: .black.opacity(0.5), radius: 24, y: 8)
        )
        .padding(.horizontal, 24)
    }

    private func inputField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType,
        autocapitalization: TextInputAutocapitalization,
        isSecure: Bool,
        showSecureToggle: Bool,
        showPassword: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(white: 0.45))
                .tracking(1.5)

            HStack(spacing: 0) {
                Group {
                    if isSecure {
                        SecureField(placeholder, text: text)
                    } else {
                        TextField(placeholder, text: text)
                            .keyboardType(keyboardType)
                            .textInputAutocapitalization(autocapitalization)
                            .autocorrectionDisabled()
                    }
                }
                .font(.body)
                .foregroundColor(.white)

                if showSecureToggle {
                    Button {
                        showPassword.wrappedValue.toggle()
                    } label: {
                        Image(systemName: showPassword.wrappedValue ? "eye.slash" : "eye")
                            .font(.body)
                            .foregroundColor(Color(white: 0.4))
                    }
                    .padding(.leading, 8)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(white: 0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(focusedField != nil ? Constants.Colors.athleanRed.opacity(0.5) : Color(white: 0.2), lineWidth: 1)
            )
        }
    }

    private var signInButton: some View {
        Button {
            focusedField = nil
            Task { await authViewModel.login() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.subheadline)
                Text("Sign In")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#E53935"), Color(hex: "#B71C1C")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(color: Color(hex: "#E53935").opacity(0.4), radius: 8, y: 4)
        }
        .disabled(authViewModel.isLoading)
        .padding(.top, 4)
    }

    private var footerLinks: some View {
        VStack(spacing: 16) {
            Button("Forgot password?") {
                if let url = URL(string: "https://portal.athleanx.com/forgot-password") {
                    UIApplication.shared.open(url)
                }
            }
            .font(.subheadline)
            .foregroundColor(Color(white: 0.5))

            HStack(spacing: 4) {
                Text("Don't have an account?")
                    .foregroundColor(Color(white: 0.4))
                Link("Join ATHLEAN-X", destination: URL(string: "https://athleanx.com")!)
                    .foregroundColor(Constants.Colors.athleanRed)
            }
            .font(.subheadline)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 3)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(Constants.Colors.athleanRed, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                        .animation(
                            Animation.linear(duration: 1).repeatForever(autoreverses: false),
                            value: authViewModel.isLoading
                        )
                }
                VStack(spacing: 4) {
                    Text("Signing you in…")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Connecting to portal.athleanx.com")
                        .font(.caption)
                        .foregroundColor(Color(white: 0.5))
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.1))
                    .shadow(radius: 20)
            )
        }
    }
}

// MARK: - Shared logo mark (used here, in splash, and in nav bar)

struct AthleanLogoMark: View {
    let size: CGFloat
    var foregroundColor: Color = Constants.Colors.athleanRed

    var body: some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: size * 0.7, weight: .black))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(hex: "#FF5252"), foregroundColor, Color(hex: "#B71C1C")],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: size, height: size)
    }
}
