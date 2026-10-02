//
//  SKLivePhoto.swift
//  SKPhotoBrowser
//

import UIKit
import Photos

// MARK: - SKLivePhoto
@available(iOS 9.1, *)
open class SKLivePhoto: NSObject, SKPhotoProtocol {
    open var index: Int = 0
    open var underlyingImage: UIImage!
    open var caption: String?
    open var contentMode: UIView.ContentMode = .scaleAspectFill

    /// The loaded PHLivePhoto, available after loadUnderlyingImageAndNotify() completes.
    open var livePhoto: PHLivePhoto?

    /// PHAsset-based initialisation (camera roll).
    open var asset: PHAsset?

    private var imageFileURL: URL?
    private var videoFileURL: URL?

    public override init() {
        super.init()
    }

    /// Initialise with a PHAsset that represents a Live Photo.
    public convenience init(asset: PHAsset) {
        self.init()
        self.asset = asset
    }

    /// Initialise with local file URLs: the still image (.heic / .jpg) and the paired video (.mov).
    public convenience init(imageURL: URL, videoURL: URL) {
        self.init()
        self.imageFileURL = imageURL
        self.videoFileURL = videoURL
    }

    // MARK: - SKPhotoProtocol

    open func checkCache() {}

    open func loadUnderlyingImageAndNotify() {
        if let asset = asset {
            loadFromAsset(asset)
        } else if let imageURL = imageFileURL, let videoURL = videoFileURL {
            loadFromURLs(imageURL: imageURL, videoURL: videoURL)
        } else if underlyingImage != nil || livePhoto != nil {
            loadUnderlyingImageComplete()
        }
    }

    // MARK: - Private loading

    private func loadFromAsset(_ asset: PHAsset) {
        // Request still image for the placeholder
        let imageOptions = PHImageRequestOptions()
        imageOptions.isNetworkAccessAllowed = true
        imageOptions.deliveryMode = .opportunistic
        imageOptions.isNetworkAccessAllowed = true

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: imageOptions
        ) { [weak self] image, _ in
            guard let self = self, let image = image else { return }
            self.underlyingImage = image
        }

        // Request the live photo
        let liveOptions = PHLivePhotoRequestOptions()
        liveOptions.isNetworkAccessAllowed = true
        liveOptions.deliveryMode = .highQualityFormat

        PHImageManager.default().requestLivePhoto(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: liveOptions
        ) { [weak self] livePhoto, info in
            guard let self = self else { return }
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            // Skip intermediate degraded previews; wait for the final result.
            if isDegraded { return }
            if let livePhoto = livePhoto {
                self.livePhoto = livePhoto
            }
            // Always fire completion on the final callback so the browser can
            // display the static image or show a failure indicator.
            DispatchQueue.main.async { self.loadUnderlyingImageComplete() }
        }
    }

    private func loadFromURLs(imageURL: URL, videoURL: URL) {
        PHLivePhoto.request(
            withResourceFileURLs: [imageURL, videoURL],
            placeholderImage: nil,
            targetSize: .zero,
            contentMode: .aspectFit
        ) { [weak self] livePhoto, info in
            guard let self = self else { return }
            let isDegraded = (info[PHLivePhotoInfoIsDegradedKey] as? Bool) ?? false
            // Skip intermediate degraded previews; wait for the final result.
            if isDegraded { return }
            if let livePhoto = livePhoto {
                self.livePhoto = livePhoto
                if self.underlyingImage == nil,
                   let data = try? Data(contentsOf: imageURL),
                   let image = UIImage(data: data) {
                    self.underlyingImage = image
                }
            }
            // Always fire completion on the final callback so the browser can
            // display the static image or show a failure indicator.
            DispatchQueue.main.async { self.loadUnderlyingImageComplete() }
        }
    }

    open func loadUnderlyingImageComplete() {
        NotificationCenter.default.post(
            name: Notification.Name(rawValue: SKPHOTO_LOADING_DID_END_NOTIFICATION),
            object: self
        )
    }

    /// Save this Live Photo into the photo library as a Live Photo (still + paired video).
    open func saveToPhotoLibrary(completion: ((Bool, Error?) -> Void)? = nil) {
        if let imageURL = imageFileURL, let videoURL = videoFileURL {
            saveFromFiles(imageURL: imageURL, videoURL: videoURL, completion: completion)
            return
        }
        if let asset = asset {
            saveFromAsset(asset, completion: completion)
            return
        }
        if let image = underlyingImage {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            completion?(true, nil)
            return
        }
        completion?(false, nil)
    }

    private func saveFromFiles(imageURL: URL, videoURL: URL, completion: ((Bool, Error?) -> Void)?) {
        resolveLocalFile(imageURL) { [weak self] imageLocal in
            guard let self = self else { return }
            self.resolveLocalFile(videoURL) { videoLocal in
                guard let imageLocal = imageLocal, let videoLocal = videoLocal else {
                    DispatchQueue.main.async { completion?(false, nil) }
                    return
                }
                self.createLivePhotoAsset(imageURL: imageLocal, videoURL: videoLocal, completion: completion)
            }
        }
    }

    private func saveFromAsset(_ asset: PHAsset, completion: ((Bool, Error?) -> Void)?) {
        let resources = PHAssetResource.assetResources(for: asset)
        let photoResource = resources.first(where: { $0.type == .photo })
            ?? resources.first(where: { $0.type == .fullSizePhoto })
        let videoResource = resources.first(where: { $0.type == .pairedVideo })
            ?? resources.first(where: { $0.type == .fullSizePairedVideo })

        guard let photoResource = photoResource, let videoResource = videoResource else {
            if let image = underlyingImage {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                completion?(true, nil)
            } else {
                completion?(false, nil)
            }
            return
        }

        let photoURL = temporaryFileURL(pathExtension: (photoResource.originalFilename as NSString).pathExtension)
        let videoURL = temporaryFileURL(pathExtension: (videoResource.originalFilename as NSString).pathExtension)
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        let manager = PHAssetResourceManager.default()

        manager.writeData(for: photoResource, toFile: photoURL, options: options) { [weak self] error in
            if let error = error {
                DispatchQueue.main.async { completion?(false, error) }
                return
            }
            manager.writeData(for: videoResource, toFile: videoURL, options: options) { error in
                if let error = error {
                    try? FileManager.default.removeItem(at: photoURL)
                    DispatchQueue.main.async { completion?(false, error) }
                    return
                }
                self?.createLivePhotoAsset(imageURL: photoURL, videoURL: videoURL) { success, error in
                    try? FileManager.default.removeItem(at: photoURL)
                    try? FileManager.default.removeItem(at: videoURL)
                    completion?(success, error)
                }
            }
        }
    }

    private func createLivePhotoAsset(imageURL: URL, videoURL: URL, completion: ((Bool, Error?) -> Void)?) {
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: imageURL, options: nil)
            request.addResource(with: .pairedVideo, fileURL: videoURL, options: nil)
        }, completionHandler: { success, error in
            DispatchQueue.main.async { completion?(success, error) }
        })
    }

    private func resolveLocalFile(_ url: URL, completion: @escaping (URL?) -> Void) {
        if url.isFileURL {
            completion(url)
            return
        }
        URLSession.shared.downloadTask(with: url) { tempURL, _, _ in
            guard let tempURL = tempURL else {
                completion(nil)
                return
            }
            let ext = url.pathExtension.isEmpty ? "dat" : url.pathExtension
            let dest = self.temporaryFileURL(pathExtension: ext)
            do {
                try FileManager.default.moveItem(at: tempURL, to: dest)
                completion(dest)
            } catch {
                completion(nil)
            }
        }.resume()
    }

    private func temporaryFileURL(pathExtension: String) -> URL {
        let ext = pathExtension.isEmpty ? "dat" : pathExtension
        let name = UUID().uuidString + "." + ext
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
    }
}
