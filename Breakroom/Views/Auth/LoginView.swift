import SwiftUI

struct LoginView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var handle = ""
    @State private var password = ""
    @State private var showSignup = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image("LogoLarge")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .accessibilityIdentifier("appLogo")

                VStack(spacing: 16) {
                    TextField("Handle", text: $handle)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .accessibilityIdentifier("usernameField")

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .padding()
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .accessibilityIdentifier("passwordField")
                }

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("errorMessage")
                }

                Button {
                    Task {
                        await authViewModel.login(handle: handle, password: password)
                    }
                } label: {
                    if authViewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Log In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(handle.isEmpty || password.isEmpty || authViewModel.isLoading)
                .accessibilityIdentifier("loginButton")

                Spacer()

                Button("Don't have an account? Sign Up") {
                    showSignup = true
                }
                .font(.callout)
            }
            .padding(.horizontal, 32)
            .navigationDestination(isPresented: $showSignup) {
                SignupView()
            }
        }
    }
}
