import SwiftUI

/// The hero background with "SuperCollider" + CTA buttons.
/// The file browser appears as a sheet floating over this.
struct HomeView: View {
    @EnvironmentObject var app: AppState
    @State private var showTemplates = false
    @StateObject private var fileManager = SCFileManager()

    var body: some View {
        // Background + hero card
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color(red: 0.15, green: 0.05, blue: 0.25),
                         Color(red: 0.05, green: 0.1, blue: 0.2),
                         Color(red: 0.1, green: 0.15, blue: 0.22)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Hero card
            VStack(spacing: 16) {
                // Top action row
                HStack {
                    Button { app.showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                }

                Spacer()

                Text("SuperCollider")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)

                Text("Audio synthesis on iOS")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))

                VStack(spacing: 10) {
                    Button {
                        showTemplates = true
                    } label: {
                        Text("Choose a Template")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "MMdd-HHmm"
                        let name = "sketch-\(formatter.string(from: Date())).scd"
                        if let file = fileManager.createFile(name: name) {
                            app.codeText = "// New sketch\n\n"
                            app.lastSavedText = app.codeText
                            app.currentFile = file.path
                            app.hasUnsavedChanges = false
                            app.isEditing = true
                            app.showEditor = true
                        }
                    } label: {
                        Text("Start Coding")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)
        }
        .sheet(isPresented: $showTemplates) {
            TemplatePickerView(isPresented: $showTemplates) { filename, content in
                if let file = fileManager.createFile(name: filename) {
                    let _ = fileManager.saveFile(file, content: content)
                    app.codeText = content
                    app.lastSavedText = content
                    app.currentFile = file.path
                    app.hasUnsavedChanges = false
                    app.isEditing = true
                    app.showEditor = true
                }
            }
            .environmentObject(app)
        }
    }
}
