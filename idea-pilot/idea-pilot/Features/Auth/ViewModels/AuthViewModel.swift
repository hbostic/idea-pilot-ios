//
//  AuthViewModel.swift
//  idea-pilot
//
//  ViewModel driving Sign In and Sign Up screens.
//  Handles form validation, loading states, error display, and auth state.
//

import Foundation

/// Drives the Sign In / Sign Up form with validation, loading, and error states.
///
/// Uses `@Observable` for modern SwiftUI data flow. Since the project uses
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, this class runs on MainActor
/// by default — safe for driving UI.
///
/// Usage:
/// ```swift
/// let vm = AuthViewModel(authService: authService)
/// // In SwiftUI view:
/// TextField("Email", text: $vm.email)
/// Button("Submit") { vm.submit() }
/// ```
@Observable
final class AuthViewModel {

    // MARK: - Form State

    var email = ""
    var password = ""
    var confirmPassword = ""
    var isLoginMode = true

    // MARK: - UI State

    var isLoading = false
    var emailError: String?
    var passwordError: String?
    var confirmPasswordError: String?
    var generalError: String?
    var isAuthenticated = false

    // MARK: - Dependencies

    private let authService: any AuthServiceProtocol

    // MARK: - Init

    /// Creates an AuthViewModel.
    ///
    /// - Parameter authService: The auth service for login/register API calls.
    init(authService: any AuthServiceProtocol) {
        self.authService = authService
    }

    // MARK: - Actions

    /// Validates the form and submits login or registration.
    ///
    /// Runs validation first. If any field fails, sets inline errors and returns
    /// without calling the service. On success, sets `isAuthenticated = true`.
    func submit() {
        clearErrors()

        guard validate() else { return }

        isLoading = true

        Task {
            defer { isLoading = false }

            do {
                if isLoginMode {
                    _ = try await authService.login(email: email, password: password)
                } else {
                    _ = try await authService.register(email: email, password: password)
                }
                isAuthenticated = true
            } catch let error as AuthError {
                mapAuthError(error)
            } catch {
                generalError = "Something went wrong. Please try again."
            }
        }
    }

    /// Switches between login and sign-up modes, clearing errors and confirm password.
    func toggleMode() {
        isLoginMode.toggle()
        confirmPassword = ""
        clearErrors()
    }

    /// Signs the user out, clearing tokens and local data.
    ///
    /// Best-effort logout API call, then resets `isAuthenticated` to `false`.
    func signOut() {
        Task {
            try? await authService.logout()
            isAuthenticated = false
            email = ""
            password = ""
            confirmPassword = ""
            clearErrors()
        }
    }

    /// Resets all error fields.
    func clearErrors() {
        emailError = nil
        passwordError = nil
        confirmPasswordError = nil
        generalError = nil
    }

    // MARK: - Private

    /// Validates form fields and sets inline error messages.
    ///
    /// - Returns: `true` if all fields are valid.
    private func validate() -> Bool {
        var isValid = true

        if !isValidEmail(email) {
            emailError = "Please enter a valid email address"
            isValid = false
        }

        if password.count < 8 {
            passwordError = "Password must be at least 8 characters"
            isValid = false
        }

        if !isLoginMode && confirmPassword != password {
            confirmPasswordError = "Passwords do not match"
            isValid = false
        }

        return isValid
    }

    /// Basic email format check: must contain `@` followed by `.`.
    private func isValidEmail(_ email: String) -> Bool {
        guard let atIndex = email.firstIndex(of: "@") else { return false }
        let domainPart = email[email.index(after: atIndex)...]
        return domainPart.contains(".")
    }

    /// Maps `AuthError` to user-facing error messages on the appropriate fields.
    private func mapAuthError(_ error: AuthError) {
        switch error {
        case .invalidCredentials:
            generalError = "Invalid email or password"
        case .emailAlreadyExists:
            emailError = "An account with this email already exists"
        case .networkError:
            generalError = "Network error. Please check your connection."
        case .serverError:
            generalError = "Something went wrong. Please try again."
        }
    }
}
