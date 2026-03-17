import SwiftUI

/// The hero background — content is positioned in the top half
/// so it's fully visible when the file sheet is at medium height.
struct HomeView: View {
    @EnvironmentObject var app: AppState
    @State private var showTemplates = false
    @StateObject private var fileManager = SCFileManager()

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.04, blue: 0.22),
                         Color(red: 0.05, green: 0.1, blue: 0.18),
                         Color(red: 0.08, green: 0.12, blue: 0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Hero content — packed into the top half
            VStack(spacing: 14) {
                Spacer(minLength: 0)

                Text("SuperCollider")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)

                Text("Audio synthesis on iOS")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 4)

                Button {
                    showTemplates = true
                } label: {
                    Text("Choose a Template")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
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
                        .padding(.vertical, 13)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Bottom padding to clear the sheet at medium detent
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            // Keep content in the top ~45% of screen
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.bottom, UIScreen.main.bounds.height * 0.48)
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
