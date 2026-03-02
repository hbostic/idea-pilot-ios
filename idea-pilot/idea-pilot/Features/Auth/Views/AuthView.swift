//
//  AuthView.swift
//  idea-pilot
//
//  Full-screen auth screen matching the dark theme mockup.
//  Handles both Sign In and Sign Up modes via AuthViewModel.
//

import SwiftUI

/// The authentication screen for Sign In and Sign Up.
///
/// A single view that handles both modes, driven by `AuthViewModel.isLoginMode`.
/// Full-screen with no tab bar, matching the dark theme web mockup.
struct AuthView: View {

    @Bindable var vm: AuthViewModel

    @FocusState private var focusedField: AuthField?

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                logoSection
                    .padding(.top, 48)

                if let error = vm.generalError {
                    errorBanner(error)
                }

                formSection

                submitButton

                modeToggle
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .themeBackground()
        .disabled(vm.isLoading)
    }

    // MARK: - Logo Section

    private var logoSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.fill")
                .font(.system(size: 36))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(Color.theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: .theme.radiusLg))
                .shadow(color: Color.theme.primary.opacity(0.5), radius: 20, y: 4)
                .accessibilityHidden(true)

            Text("Idea Pilot")
                .font(.theme.largeTitle)
                .foregroundStyle(Color.theme.foreground)

            Text("Helping you land on the tarmac of execution")
                .font(.theme.subheadline)
                .foregroundStyle(Color.theme.mutedForeground)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
            Text(message)
                .font(.theme.subheadline)
        }
        .foregroundStyle(Color.theme.destructive)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.theme.destructive.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: .theme.radiusMd))
        .overlay(
            RoundedRectangle(cornerRadius: .theme.radiusMd)
                .stroke(Color.theme.destructive.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(spacing: 20) {
            themedTextField(
                label: "EMAIL",
                placeholder: "you@example.com",
                text: $vm.email,
                error: vm.emailError,
                field: .email,
                keyboardType: .emailAddress,
                textContentType: .emailAddress,
                submitLabel: .next
            ) {
                focusedField = .password
            }

            themedSecureField(
                label: "PASSWORD",
                placeholder: "At least 8 characters",
                text: $vm.password,
                error: vm.passwordError,
                field: .password,
                submitLabel: vm.isLoginMode ? .go : .next
            ) {
                if vm.isLoginMode {
                    focusedField = nil
                    vm.submit()
                } else {
                    focusedField = .confirmPassword
                }
            }

            if !vm.isLoginMode {
                themedSecureField(
                    label: "CONFIRM PASSWORD",
                    placeholder: "Re-enter your password",
                    text: $vm.confirmPassword,
                    error: vm.confirmPasswordError,
                    field: .confirmPassword,
                    submitLabel: .go
                ) {
                    focusedField = nil
                    vm.submit()
                }
            }
        }
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            focusedField = nil
            vm.submit()
        } label: {
            Group {
                if vm.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(vm.isLoginMode ? "Sign In" : "Sign Up")
                        .font(.theme.body)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .foregroundStyle(Color.theme.primaryForeground)
            .background(Color.theme.primary)
            .clipShape(RoundedRectangle(cornerRadius: .theme.radiusMd))
            .shadow(color: Color.theme.primary.opacity(0.4), radius: 12, y: 4)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(vm.isLoading
            ? (vm.isLoginMode ? "Signing in" : "Signing up")
            : (vm.isLoginMode ? "Sign In" : "Sign Up"))
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        Button {
            focusedField = nil
            vm.toggleMode()
        } label: {
            Group {
                if vm.isLoginMode {
                    Text("Don't have an account? ")
                        .foregroundStyle(Color.theme.mutedForeground) +
                    Text("Sign Up")
                        .foregroundStyle(Color.theme.primary)
                        .bold()
                } else {
                    Text("Already have an account? ")
                        .foregroundStyle(Color.theme.mutedForeground) +
                    Text("Sign In")
                        .foregroundStyle(Color.theme.primary)
                        .bold()
                }
            }
            .font(.theme.subheadline)
        }
        .accessibilityLabel(vm.isLoginMode ? "Switch to Sign Up" : "Switch to Sign In")
    }

    // MARK: - Themed Text Field

    private func themedTextField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        error: String?,
        field: AuthField,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        submitLabel: SubmitLabel = .done,
        onSubmit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.theme.overline)
                .foregroundStyle(Color.theme.mutedForeground)
                .tracking(1.0)

            TextField(placeholder, text: text)
                .font(.theme.bodyRegular)
                .foregroundStyle(Color.theme.foreground)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(submitLabel)
                .onSubmit(onSubmit)
                .focused($focusedField, equals: field)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.theme.secondary)
                .clipShape(RoundedRectangle(cornerRadius: .theme.radiusMd))
                .overlay(
                    RoundedRectangle(cornerRadius: .theme.radiusMd)
                        .stroke(
                            fieldBorderColor(error: error, field: field),
                            lineWidth: focusedField == field ? 1.5 : 1
                        )
                )
                .accessibilityLabel(label)
                .accessibilityValue(error ?? "")

            if let error {
                inlineError(error)
            }
        }
    }

    // MARK: - Themed Secure Field

    private func themedSecureField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        error: String?,
        field: AuthField,
        submitLabel: SubmitLabel = .done,
        onSubmit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.theme.overline)
                .foregroundStyle(Color.theme.mutedForeground)
                .tracking(1.0)

            PasswordField(
                placeholder: placeholder,
                text: text,
                field: field,
                focusedField: $focusedField,
                submitLabel: submitLabel,
                onSubmit: onSubmit
            )
            .overlay(
                RoundedRectangle(cornerRadius: .theme.radiusMd)
                    .stroke(
                        fieldBorderColor(error: error, field: field),
                        lineWidth: focusedField == field ? 1.5 : 1
                    )
            )
            .accessibilityLabel(label)
            .accessibilityValue(error ?? "")

            if let error {
                inlineError(error)
            }
        }
    }

    // MARK: - Helpers

    private func fieldBorderColor(error: String?, field: AuthField) -> Color {
        if error != nil {
            return Color.theme.destructive
        }
        if focusedField == field {
            return Color.theme.ring
        }
        return Color.theme.input
    }

    private func inlineError(_ message: String) -> some View {
        Text(message)
            .font(.theme.caption)
            .foregroundStyle(Color.theme.destructive)
    }
}

// MARK: - Focus Field Enum

enum AuthField: Hashable {
    case email, password, confirmPassword
}

// MARK: - Password Field (Toggle Visibility)

/// A password input with a toggle to show/hide the password text.
private struct PasswordField: View {

    let placeholder: String
    @Binding var text: String
    let field: AuthField
    var focusedField: FocusState<AuthField?>.Binding
    let submitLabel: SubmitLabel
    let onSubmit: () -> Void

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if isVisible {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .font(.theme.bodyRegular)
            .foregroundStyle(Color.theme.foreground)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(submitLabel)
            .onSubmit(onSubmit)
            .focused(focusedField, equals: field)

            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.theme.mutedForeground)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isVisible ? "Hide password" : "Show password")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.theme.secondary)
        .clipShape(RoundedRectangle(cornerRadius: .theme.radiusMd))
    }
}

// MARK: - Preview

#Preview("Sign In") {
    AuthView(vm: {
        let vm = AuthViewModel(authService: PreviewAuthService())
        return vm
    }())
}

#Preview("Sign Up") {
    AuthView(vm: {
        let vm = AuthViewModel(authService: PreviewAuthService())
        vm.isLoginMode = false
        return vm
    }())
}

#Preview("With Errors") {
    AuthView(vm: {
        let vm = AuthViewModel(authService: PreviewAuthService())
        vm.emailError = "Please enter a valid email address"
        vm.passwordError = "Password must be at least 8 characters"
        vm.generalError = "Network error. Please check your connection."
        return vm
    }())
}

/// A no-op auth service for SwiftUI previews.
private struct PreviewAuthService: AuthServiceProtocol {
    func login(email: String, password: String) async throws -> UserSession {
        UserSession(userId: "preview", email: email, accessToken: "a", refreshToken: "r")
    }
    func register(email: String, password: String) async throws -> UserSession {
        UserSession(userId: "preview", email: email, accessToken: "a", refreshToken: "r")
    }
    func auth0Login(idToken: String) async throws -> UserSession {
        UserSession(userId: "preview", email: "preview@test.com", accessToken: "a", refreshToken: "r")
    }
    func logout() async throws {}
}
