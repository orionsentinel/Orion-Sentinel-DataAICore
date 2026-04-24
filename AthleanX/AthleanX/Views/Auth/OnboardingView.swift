import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showLogin = false

    var body: some View {
        if showLogin {
            LoginView(showLogin: $showLogin)
                .environmentObject(authViewModel)
        } else {
            splashView
        }
    }

    private var splashView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 64))
                        .foregroundColor(Constants.Colors.athleanRed)
                    Text("ATHLEAN-X")
                        .font(.system(size: 36, weight: .black))
                        .foregroundColor(.white)
                        .tracking(4)
                    Text("Train Like an Athlete.\nLook Like a Superhero.")
                        .font(.title3)
                        .foregroundColor(Constants.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                Spacer()
                VStack(spacing: 12) {
                    Button("Get Started") {
                        showLogin = true
                    }
                    .athleanButtonStyle()
                    .padding(.horizontal, 32)

                    Button("I have an account") {
                        showLogin = true
                    }
                    .font(.subheadline)
                    .foregroundColor(Constants.Colors.textSecondary)
                }
                .padding(.bottom, 48)
            }
        }
    }
}

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var showLogin: Bool
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Constants.Colors.athleanRed)
                        Text("Welcome Back")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)
                        Text("Sign in to your ATHLEAN-X account")
                            .font(.subheadline)
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                    .padding(.top, 60)

                    VStack(spacing: 16) {
                        AthleanTextField(
                            title: "Email",
                            text: $authViewModel.email,
                            keyboardType: .emailAddress,
                            placeholder: "you@example.com"
                        )
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }

                        AthleanTextField(
                            title: "Password",
                            text: $authViewModel.password,
                            isSecure: true,
                            placeholder: "••••••••"
                        )
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { Task { await authViewModel.login() } }

                        Toggle("Remember me", isOn: $authViewModel.rememberMe)
                            .tint(Constants.Colors.athleanRed)
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                    .padding(.horizontal, 24)

                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    VStack(spacing: 12) {
                        Button {
                            Task { await authViewModel.login() }
                        } label: {
                            if authViewModel.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Sign In")
                            }
                        }
                        .disabled(authViewModel.isLoading)
                        .athleanButtonStyle()
                        .padding(.horizontal, 24)

                        Button("Forgot password?") {}
                            .font(.subheadline)
                            .foregroundColor(Constants.Colors.athleanRed)
                    }

                    Spacer(minLength: 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showLogin = false }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                }
            }
        }
        .navigationBarBackButtonHidden()
    }
}

struct AthleanTextField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure = false
    var placeholder: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundColor(Constants.Colors.textSecondary)
                .tracking(1)
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
            }
            .padding(14)
            .background(Constants.Colors.cardBackground)
            .cornerRadius(8)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Constants.Colors.secondaryBackground, lineWidth: 1)
            )
        }
    }
}
