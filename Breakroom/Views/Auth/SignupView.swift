import SwiftUI

struct SignupView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var handle = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    private var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }

    private var formValid: Bool {
        !handle.isEmpty && !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty && passwordsMatch
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 24)

                VStack(spacing: 16) {
                    TextField("Handle", text: $handle)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                        .padding()
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                        .padding()
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .padding()
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                        .padding()
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .padding()
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    if !confirmPassword.isEmpty && !passwordsMatch {
                        Text("Passwords do not match")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task {
                        await authViewModel.signup(
                            handle: handle,
                            firstName: firstName,
                            lastName: lastName,
                            email: email,
                            password: password
                        )
                    }
                } label: {
                    if authViewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Sign Up")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!formValid || authViewModel.isLoading)
            }
            .padding(.horizontal, 32)
        }
    }
}
