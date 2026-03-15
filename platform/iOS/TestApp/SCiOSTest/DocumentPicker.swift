import SwiftUI
import UniformTypeIdentifiers

/// Document picker for importing SC scripts
struct DocumentImporter: ViewModifier {
    @Binding var isPresented: Bool
    var onImport: (URL) -> Void

    func body(content: Content) -> some View {
        content.fileImporter(
            isPresented: $isPresented,
            allowedContentTypes: [
                UTType(filenameExtension: "scd") ?? .plainText,
                UTType(filenameExtension: "sc") ?? .plainText,
                .plainText
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    onImport(url)
                }
            case .failure(let error):
                print("Import error: \(error)")
            }
        }
    }
}

/// Share sheet for exporting scripts
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension View {
    func scDocumentImporter(isPresented: Binding<Bool>, onImport: @escaping (URL) -> Void) -> some View {
        modifier(DocumentImporter(isPresented: isPresented, onImport: onImport))
    }
}
