import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct DocumentPickerView: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    var allowsMultipleSelection: Bool = false
    let onPick: ([URL]) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onCancel: onCancel) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = allowsMultipleSelection
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        let onCancel: () -> Void
        init(onPick: @escaping ([URL]) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            print("[DocPicker] didPickDocumentsAt: \(urls)")
            onPick(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("[DocPicker] cancelled")
            onCancel()
        }
    }
}

