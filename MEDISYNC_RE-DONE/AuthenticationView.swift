import SwiftUI
import UIKit

struct AuthenticationView: View {
    @State private var phoneNumber = ""
    @State private var otpCode = ""
    @State private var showOTPField = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Country Logic
    @State private var selectedCountryCode = "+91"
    let countryCodes = ["+1", "+44", "+91", "+61", "+81", "+86", "+49"]
    
    // Auth Mode
    @State private var authMode: AuthMode = .email // Defaulting to email as requested
    
    enum AuthMode {
        case phone
        case email
    }
    
    // Email State
    @State private var email = ""
    @State private var password = ""
    @State private var emailAuthMode: EmailAuthMode = .signIn
    
    enum EmailAuthMode {
        case signIn
        case signUp
    }
    
    @ObservedObject private var appManager = AppManager.shared
    
    // Constants
    private let vibrantPurple = Color(red: 0.65, green: 0.55, blue: 0.95)
    
    var body: some View {
        ZStack {
            // Background
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Image/Logo area
                VStack(spacing: 20) {
                    Spacer().frame(height: 60)
                    
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [vibrantPurple, Color(red: 0.8, green: 0.7, blue: 1.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: vibrantPurple.opacity(0.3), radius: 15, x: 0, y: 8)
                    
                    VStack(spacing: 8) {
                        Text("Welcome Back")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        
                        Text("Secure access to your health journey.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.bottom, 50)
                
                // Main Card
                VStack(spacing: 30) {
                    
                    // 1. Method Selector (Email vs Phone) - NOW ON TOP
                    HStack(spacing: 0) {
                        AuthMethodButton(title: "Email", isSelected: authMode == .email) {
                            withAnimation { authMode = .email }
                        }
                        
                        AuthMethodButton(title: "Phone", isSelected: authMode == .phone) {
                            withAnimation { authMode = .phone }
                        }
                    }
                    .padding(4)
                    .background(Color.gray.opacity(0.12))
                    .cornerRadius(16)
                    .padding(.horizontal, 24)
                    
                    // 2. Action Selector (Log In vs Sign Up) - NOW BELOW
                    HStack(spacing: 12) {
                        Button(action: { withAnimation { emailAuthMode = .signIn } }) {
                            Text("Log In")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(emailAuthMode == .signIn ? .white : .gray)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(emailAuthMode == .signIn ? vibrantPurple : Color.gray.opacity(0.08))
                                .cornerRadius(14)
                        }
                        
                        Button(action: { withAnimation { emailAuthMode = .signUp } }) {
                            Text("Sign Up")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(emailAuthMode == .signUp ? .white : .gray)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(emailAuthMode == .signUp ? vibrantPurple : Color.gray.opacity(0.08))
                                .cornerRadius(14)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // 3. Input Fields Area
                    VStack(spacing: 20) {
                        if authMode == .phone {
                            phoneAuthView
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        } else {
                            emailAuthView
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 24)
                    .frame(minHeight: 220)
                    
                    // 4. Secondary Actions
                    VStack(spacing: 12) {
                        Text("OR")
                            .font(.caption2.bold())
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Button(action: {
                            appManager.enterGuestMode()
                        }) {
                            Text("Continue as Guest")
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.black)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(vibrantPurple)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: vibrantPurple.opacity(0.4), radius: 12, x: 0, y: 6)
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.top, 10)
                }
                
                Spacer()
                
                // Footer
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        Button("Terms") { }
                        Text("•")
                        Button("Privacy") { }
                    }
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.6))
                }
                .padding(.bottom, 20)
            }
            
            // Back Button
            VStack {
                HStack {
                    Button(action: {
                        appManager.backToPrologue()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                            .padding(12)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 24)
                    .padding(.top, 60)
                    Spacer()
                }
                Spacer()
            }
        }
        .alert(isPresented: $showError) {
            Alert(title: Text("Authentication Failed"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    // MARK: - Email Auth View
    var emailAuthView: some View {
        VStack(spacing: 20) {
            CustomTextField(icon: "envelope.fill", placeholder: "Email Address", text: $email, contentType: .emailAddress)
            
            CustomSecureField(icon: "lock.fill", placeholder: "Password", text: $password)
            
            Button(action: emailContinue) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(emailAuthMode == .signIn ? "Log In" : "Create Account")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(vibrantPurple)
                        .cornerRadius(16)
                        .shadow(color: vibrantPurple.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
            .disabled(email.isEmpty || password.isEmpty || isLoading)
            .opacity((email.isEmpty || password.isEmpty) ? 0.6 : 1.0)
            
            Text(emailAuthMode == .signIn ? "Forgot your password?" : "By creating an account, you agree to our Terms.")
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Phone Auth View (Refined)
    var phoneAuthView: some View {
        VStack(spacing: 20) {
            if !showOTPField {
                HStack(spacing: 12) {
                    // Country Code
                    Menu {
                        ForEach(countryCodes, id: \.self) { code in
                            Button(code) { selectedCountryCode = code }
                        }
                    } label: {
                        HStack {
                            Text(selectedCountryCode)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(16)
                    }
                    
                    // Phone Number
                    TextField("Mobile Number", text: $phoneNumber)
                        .keyboardType(.numberPad)
                        .font(.headline)
                        .padding()
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(16)
                }
                
                Button(action: sendOTP) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Get OTP")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(vibrantPurple)
                            .cornerRadius(16)
                            .shadow(color: vibrantPurple.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                .disabled(phoneNumber.count < 10 || isLoading)
                .opacity(phoneNumber.count < 10 ? 0.6 : 1.0)
                
            } else {
                VStack(spacing: 16) {
                    Text("Enter code sent to \(selectedCountryCode) \(phoneNumber)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    TextField("000000", text: $otpCode)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(16)
                    
                    Button(action: verifyOTP) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Verify & Continue")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(vibrantPurple)
                                .cornerRadius(16)
                        }
                    }
                    .disabled(otpCode.count < 6 || isLoading)
                    
                    Button("Resend Code") {
                        showOTPField = false
                        otpCode = ""
                    }
                    .font(.caption)
                    .foregroundColor(vibrantPurple)
                }
            }
        }
    }
    
    // MARK: - Logic
    
    func sendOTP() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            showOTPField = true
        }
    }
    
    func verifyOTP() {
        isLoading = true
        Task {
            do {
                let uid = try await FirebaseAuthService.shared.ensureAnonymousUser()
                if !uid.isEmpty {
// Auth state listener in AppManager will handle transition to Setup
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
    
    func emailContinue() {
        isLoading = true
        Task {
            // Magic Auth Flow: 
            // 1. If Sign In: Try Sign In.
            // 2. If Sign Up: Try Sign Up. If that fails, automatically try Sign In.
            // 3. IF ALL FAILS: Force entry anyway to satisfy "any email works" demo requirement.
            
            do {
                if emailAuthMode == .signIn {
                    _ = try await FirebaseAuthService.shared.signIn(email: email, password: password)
                } else {
                    do {
                        _ = try await FirebaseAuthService.shared.signUp(email: email, password: password)
                    } catch {
                        _ = try await FirebaseAuthService.shared.signIn(email: email, password: password)
                    }
                }
                
                await MainActor.run { isLoading = false }
            } catch {
                // FORCE ENTRY FALLBACK
                print("Demo Mode: Bypassing auth error (\(error.localizedDescription))")
                await MainActor.run {
                    isLoading = false
                    appManager.enterDemoMode() // Unlimited uploads for demo users
                }
            }
        }
    }
}

// MARK: - Custom Internal Components

struct AuthMethodButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundColor(isSelected ? .black : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.white : Color.clear)
                .cornerRadius(12)
                .shadow(color: .black.opacity(isSelected ? 0.05 : 0), radius: 2, x: 0, y: 1)
        }
    }
}

struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var contentType: UITextContentType? = nil
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .textContentType(contentType)
                .textInputAutocapitalization(.never)
        }
        .padding()
        .background(Color.gray.opacity(0.08))
        .cornerRadius(16)
    }
}

struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            
            SecureField(placeholder, text: $text)
                .textContentType(.password)
        }
        .padding()
        .background(Color.gray.opacity(0.08))
        .cornerRadius(16)
    }
}
