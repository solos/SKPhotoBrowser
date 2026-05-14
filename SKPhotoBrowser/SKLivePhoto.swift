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

    override init() {
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
            guard let self = self, let livePhoto = livePhoto else { return }
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            if !isDegraded {
                self.livePhoto = livePhoto
                DispatchQueue.main.async { self.loadUnderlyingImageComplete() }
            }
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
            if !isDegraded, let livePhoto = livePhoto {
                self.livePhoto = livePhoto
                if self.underlyingImage == nil,
                   let data = try? Data(contentsOf: imageURL),
                   let image = UIImage(data: data) {
                    self.underlyingImage = image
                }
                DispatchQueue.main.async { self.loadUnderlyingImageComplete() }
            }
        }
    }

    open func loadUnderlyingImageComplete() {
        NotificationCenter.default.post(
            name: Notification.Name(rawValue: SKPHOTO_LOADING_DID_END_NOTIFICATION),
            object: self
        )
    }
}
