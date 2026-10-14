import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct AvatarImage: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let image = UIImage(data: data) else {
                throw AvatarTransferError.decodeFailed
            }
            return AvatarImage(image: image)
        }
    }

    enum AvatarTransferError: Error {
        case decodeFailed
    }
}

/// 系统相册选择（比 PhotosPicker + Data 更稳）
struct PhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPicker
        init(_ parent: PhotoLibraryPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard let provider = results.first?.itemProvider else { return }
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    guard let image = object as? UIImage else { return }
                    DispatchQueue.main.async {
                        self.parent.image = image
                    }
                }
            }
        }
    }
}

/// 相册多选，按选择顺序回传
struct MultiPhotoLibraryPicker: UIViewControllerRepresentable {
    var limit: Int
    var onPicked: ([UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = max(1, limit)
        config.selection = .ordered
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MultiPhotoLibraryPicker
        init(_ parent: MultiPhotoLibraryPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            let providers = results.map(\.itemProvider).filter { $0.canLoadObject(ofClass: UIImage.self) }
            guard !providers.isEmpty else { return }

            var images = [UIImage?](repeating: nil, count: providers.count)
            let group = DispatchGroup()
            for (index, provider) in providers.enumerated() {
                group.enter()
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    DispatchQueue.main.async {
                        images[index] = object as? UIImage
                        group.leave()
                    }
                }
            }
            group.notify(queue: .main) {
                self.parent.onPicked(images.compactMap { $0 })
            }
        }
    }
}
