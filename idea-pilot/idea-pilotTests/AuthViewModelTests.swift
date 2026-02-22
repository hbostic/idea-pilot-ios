//
//  AuthViewModelTests.swift
//  idea-pilotTests
//
//  Unit tests for AuthViewModel with mock AuthService.
//

import Foundation
import Testing
@testable import idea_pilot

// MARK: - Mock Auth Service

/// Mock implementation of `AuthServiceProtocol` for ViewModel testing.
final class MockAuthService: AuthServiceProtocol, @unchecked Sendable {

    nonisolated(unsafe) var loginResult: Result<UserSession, AuthError> = .success(
        UserSession(userId: "user-1", email: "test@example.com", accessToken: "access", refreshToken: "refresh")
    )
    nonisolated(unsafe) var registerResult: Result<UserSession, AuthError> = .success(
        UserSession(userId: "user-1", email: "test@example.com", accessToken: "access", refreshToken: "refresh")
    )
    nonisolated(unsafe) var auth0Result: Result<UserSession, AuthError> = .success(
        UserSession(userId: "user-1", email: "test@example.com", accessToken: "access", refreshToken: "refresh")
    )

    nonisolated(unsafe) var loginCallCount = 0
    nonisolated(unsafe) var registerCallCount = 0
    nonisolated(unsafe) var auth0LoginCallCount = 0
    nonisolated(unsafe) var logoutCallCount = 0

    nonisolated(unsafe) var capturedEmail: String?
    nonisolated(unsafe) var capturedPassword: String?

    nonisolated func login(email: String, password: String) async throws -> UserSession {
        loginCallCount += 1
        capturedEmail = email
        capturedPassword = password
        return try loginResult.get()
    }

    nonisolated func register(email: String, password: String) async throws -> UserSession {
        registerCallCount += 1
        capturedEmail = email
        capturedPassword = password
        return try registerResult.get()
    }

    nonisolated func auth0Login(idToken: String) async throws -> UserSession {
        auth0LoginCallCount += 1
        return try auth0Result.get()
    }

    nonisolated func logout() async throws {
        logoutCallCount += 1
    }
}

// MARK: - AuthViewModel Tests

@Suite("AuthViewModel", .serialized)
struct AuthViewModelTests {

    // MARK: - Login Success

    @Test("submit with valid credentials calls login and sets isAuthenticated")
    @MainActor func loginSuccess() async throws {
        let mockService = MockAuthService()
        let vm = AuthViewModel(authService: mockService)
        vm.email = "test@example.com"
        vm.password = "password123"

        vm.submit()

        // Wait for the async Task to complete.
        try await Task.sleep(for: .milliseconds(50))

        #expect(mockService.loginCallCount == 1)
        #expect(mockService.capturedEmail == "test@example.com")
        #expect(mockService.capturedPassword == "password123")
        #expect(vm.isAuthenticated == true)
        #expect(vm.isLoading == false)
        #expect(vm.generalError == nil)
    }

    // MARK: - Register Success

    @Test("submit in signup mode calls register and sets isAuthenticated")
    @MainActor func registerSuccess() async throws {
        let mockService = MockAuthService()
        let vm = AuthViewModel(authService: mockService)
        vm.isLoginMode = false
        vm.email = "new@example.com"
        vm.password = "password123"
        vm.confirmPassword = "password123"

        vm.submit()
        try await Task.sleep(for: .milliseconds(50))

        #expect(mockService.registerCallCount == 1)
        #expect(mockService.capturedEmail == "new@example.com")
        #expect(vm.isAuthenticated == true)
        #expect(vm.isLoading == false)
    }

    // MARK: - Validation: Email

    @Test("submit with invalid email sets emailError")
    @MainActor func invalidEmailFormat() {
        let mockService = MockAuthService()
        let vm = AuthViewModel(authService: mockService)
        vm.email = "notanemail"
        vm.password = "password123"

        vm.submit()

        #expect(vm.emailError == "Please enter a valid email address")
        #expect(mockService.loginCallCount == 0)
    }

    @Test("submit with empty email sets emailError")
    @MainActor func emptyEmail() {
        let mockService = MockAuthService()
        let vm = AuthViewModel(authService: mockService)
        vm.email = ""
        vm.password = "password123"

        vm.submit()

        #expect(vm.emailError == "Please enter a valid email address")
        #expect(mockService.loginCallCount == 0)
    }

    // MARK: - Validation: Password

    @Test("submit with short password sets passwordError")
    @MainActor func shortPassword() {
        let mockService = MockAuthService()
        let vm = AuthViewModel(authService: mockService)
        vm.email = "test@example.com"
        vm.password = "short"

        vm.submit()

        #expect(vm.passwordError == "Password must be at least 8 characters")
        #expect(mockService.loginCallCount == 0)
    }

    // MARK: - Validation: Confirm Password

    @Test("submit with mismatched confirm password sets confirmPasswordError")
    @MainActor func mismatchedConfirmPassword() {
        let mockService = MockAuthService()
        let vm = AuthViewModel(authService: mockService)
        vm.isLoginMode = false
        vm.email = "test@example.com"
        vm.password = "password123"
        vm.confirmPassword = "different456"

        vm.submit()

        #expect(vm.confirmPasswordError == "Passwords do not match")
        #expect(mockService.registerCallCount == 0)
    }

    @Test("submit in login mode ignores confirm password validation")
    @MainActor func loginIgnoresConfirmPassword() async throws {
        let mockService = MockAuthService()
        let vm = AuthViewModel(authService: mockService)
        vm.isLoginMode = true
        vm.email = "test@example.com"
        vm.password = "password123"
        vm.confirmPassword = "different456"

        vm.submit()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.confirmPasswordError == nil)
        #expect(mockService.loginCallCount == 1)
    }

    // MARK: - Validation Does Not Call Service

    @Test("submit does not call service when validation fails")
    @MainActor func validationPreventsServiceCall() {
        let mockService = MockAuthService()
        let vm = AuthViewModel(authService: mockService)
        vm.email = "bad"
        vm.password = "short"

        vm.submit()

        #expect(mockService.loginCallCount == 0)
        #expect(mockService.registerCallCount == 0)
        #expect(vm.emailError != nil)
        #expect(vm.passwordError != nil)
    }

    // MARK: - Error Mapping: Invalid Credentials

    @Test("login failure with invalidCredentials sets generalError")
    @MainActor func loginInvalidCredentials() async throws {
        let mockService = MockAuthService()
        mockService.loginResult = .failure(.invalidCredentials)
        let vm = AuthViewModel(authService: mockService)
        vm.email = "test@example.com"
        vm.password = "password123"

        vm.submit()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.generalError == "Invalid email or password")
        #expect(vm.isAuthenticated == false)
        #expect(vm.isLoading == false)
    }

    // MARK: - Error Mapping: Email Already Exists

    @Test("register failure with emailAlreadyExists sets emailError")
    @MainActor func registerEmailExists() async throws {
        let mockService = MockAuthService()
        mockService.registerResult = .failure(.emailAlreadyExists)
        let vm = AuthViewModel(authService: mockService)
        vm.isLoginMode = false
        vm.email = "taken@example.com"
        vm.password = "password123"
        vm.confirmPassword = "password123"

        vm.submit()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.emailError == "An account with this email already exists")
        #expect(vm.isAuthenticated == false)
    }

    // MARK: - Error Mapping: Network Error

    @Test("login network error sets generalError")
    @MainActor func loginNetworkError() async throws {
        let mockService = MockAuthService()
        mockService.loginResult = .failure(.networkError("timeout"))
        let vm = AuthViewModel(authService: mockService)
        vm.email = "test@example.com"
        vm.password = "password123"

        vm.submit()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.generalError == "Network error. Please check your connection.")
        #expect(vm.isAuthenticated == false)
    }

    // MARK: - Loading State

    @Test("isLoading is true during API call")
    @MainActor func loadingDuringAPICall() async throws {
        let mockService = MockAuthService()
        let vm = AuthViewModel(authService: mockService)
        vm.email = "test@example.com"
        vm.password = "password123"

        vm.submit()

        // isLoading should be true immediately after submit (before async completes).
        #expect(vm.isLoading == true)

        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.isLoading == false)
    }

    // MARK: - Toggle Mode

    @Test("toggleMode switches mode, clears errors and confirmPassword")
    @MainActor func toggleModeClearsState() {
        let mockService = MockAuthService()
        let vm = AuthViewModel(authService: mockService)
        vm.confirmPassword = "something"
        vm.emailError = "some error"
        vm.passwordError = "another error"
        vm.generalError = "general"

        vm.toggleMode()

        #expect(vm.isLoginMode == false)
        #expect(vm.confirmPassword == "")
        #expect(vm.emailError == nil)
        #expect(vm.passwordError == nil)
        #expect(vm.generalError == nil)
    }

    // MARK: - Clear Errors

    @Test("clearErrors resets all error fields")
    @MainActor func clearErrorsResetsAll() {
        let mockService = MockAuthService()
        let vm = AuthViewModel(authService: mockService)
        vm.emailError = "email"
        vm.passwordError = "password"
        vm.confirmPasswordError = "confirm"
        vm.generalError = "general"

        vm.clearErrors()

        #expect(vm.emailError == nil)
        #expect(vm.passwordError == nil)
        #expect(vm.confirmPasswordError == nil)
        #expect(vm.generalError == nil)
    }
}
