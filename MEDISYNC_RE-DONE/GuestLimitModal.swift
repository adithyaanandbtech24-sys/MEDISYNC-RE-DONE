import SwiftUI

struct GuestLimitModal: View {
    @Binding var isPresented: Bool
    @ObservedObject private var appManager = AppManager.shared
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Continue with MediSync")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    Text("You’ve reached the guest limit.\nCreate a free account to securely store your medical history and continue using MediSync.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                }
                
                // Actions
                VStack(spacing: 12) {
                    Button(action: {
                        isPresented = false
                        appManager.signOut() // Go to Auth Screen
                    }) {
                        Text("Create Account")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Maybe Later")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
            }
            .padding(32)
            .background(Color.white)
            .cornerRadius(24)
            .padding(.horizontal, 20)
            .shadow(radius: 20)
        }
    }
}
