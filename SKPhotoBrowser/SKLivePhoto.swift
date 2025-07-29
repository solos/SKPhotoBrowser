//
//  SKLivePhoto.swift
//  SKPhotoBrowser
//
//  Created by SKPhotoBrowser on 2024/01/01.
//  Copyright © 2024 SKPhotoBrowser. All rights reserved.
//

import UIKit
import PhotosUI

@available(iOS 9.1, *)
open class SKLivePhoto: NSObject, SKPhotoProtocol {
    open var index: Int = 0
    open var underlyingImage: UIImage!
    open var caption: String?
    open var contentMode: UIView.ContentMode = .scaleAspectFill
    open var shouldCachePhotoURLImage: Bool = false
    open var photoURL: String!
    
    // Live Photo specific properties
    open var livePhoto: PHLivePhoto?
    open var livePhotoURL: URL?
    open var isLivePhoto: Bool = false
    
    override init() {
        super.init()
    }
    
    convenience init(livePhoto: PHLivePhoto, image: UIImage? = nil) {
        self.init()
        self.livePhoto = livePhoto
        self.underlyingImage = image
        self.isLivePhoto = true
    }
    
    convenience init(livePhotoURL: URL, image: UIImage? = nil) {
        self.init()
        self.livePhotoURL = livePhotoURL
        self.underlyingImage = image
        self.isLivePhoto = true
    }
    
    open func checkCache() {
        // Live Photo cache checking logic can be implemented here
        // For now, we'll use the same logic as regular photos
        guard let photoURL = photoURL else {
            return
        }
        guard shouldCachePhotoURLImage else {
            return
        }
        
        if SKCache.sharedCache.imageCache is SKRequestResponseCacheable {
            let request = URLRequest(url: URL(string: photoURL)!)
            if let img = SKCache.sharedCache.imageForRequest(request) {
                underlyingImage = img
            }
        } else {
            if let img = SKCache.sharedCache.imageForKey(photoURL) {
                underlyingImage = img
            }
        }
    }
    
    open func loadUnderlyingImageAndNotify() {
        // For Live Photos, we might need to load from URL or asset
        if let livePhotoURL = livePhotoURL {
            // Load Live Photo from URL
            loadLivePhotoFromURL(livePhotoURL)
        } else if let photoURL = photoURL, let URL = URL(string: photoURL) {
            // Fallback to regular image loading
            loadImageFromURL(URL)
        } else {
            DispatchQueue.main.async {
                self.loadUnderlyingImageComplete()
            }
        }
    }
    
    private func loadLivePhotoFromURL(_ url: URL) {
        // This is a simplified implementation
        // In a real implementation, you might need to handle Live Photo format
        // For now, we'll load as a regular image
        let session = URLSession(configuration: SKPhotoBrowserOptions.sessionConfiguration)
        let task = session.dataTask(with: url) { [weak self] (data, response, error) in
            guard let self = self else { return }
            defer { session.finishTasksAndInvalidate() }
            
            guard error == nil, let data = data else {
                DispatchQueue.main.async {
                    self.loadUnderlyingImageComplete()
                }
                return
            }
            
            if let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.underlyingImage = image
                    self.loadUnderlyingImageComplete()
                }
            } else {
                DispatchQueue.main.async {
                    self.loadUnderlyingImageComplete()
                }
            }
        }
        task.resume()
    }
    
    private func loadImageFromURL(_ url: URL) {
        if self.shouldCachePhotoURLImage {
            if SKCache.sharedCache.imageCache is SKRequestResponseCacheable {
                let request = URLRequest(url: url)
                if let img = SKCache.sharedCache.imageForRequest(request) {
                    DispatchQueue.main.async {
                        self.underlyingImage = img
                        self.loadUnderlyingImageComplete()
                    }
                    return
                }
            } else {
                if let img = SKCache.sharedCache.imageForKey(photoURL) {
                    DispatchQueue.main.async {
                        self.underlyingImage = img
                        self.loadUnderlyingImageComplete()
                    }
                    return
                }
            }
        }

        let session = URLSession(configuration: SKPhotoBrowserOptions.sessionConfiguration)
        var task: URLSessionTask?
        task = session.dataTask(with: url) { [weak self] (data, response, error) in
            guard let self = self else { return }
            defer { session.finishTasksAndInvalidate() }

            guard error == nil else {
                DispatchQueue.main.async {
                    self.loadUnderlyingImageComplete()
                }
                return
            }

            if let data = data, let response = response, let image = UIImage.animatedImage(withAnimatedGIFData: data) {
                if self.shouldCachePhotoURLImage {
                    if SKCache.sharedCache.imageCache is SKRequestResponseCacheable {
                        SKCache.sharedCache.setImageData(data, response: response, request: task?.originalRequest)
                    } else {
                        SKCache.sharedCache.setImage(image, forKey: self.photoURL)
                    }
                }
                DispatchQueue.main.async {
                    self.underlyingImage = image
                    self.loadUnderlyingImageComplete()
                }
            }
        }
        task?.resume()
    }

    open func loadUnderlyingImageComplete() {
        NotificationCenter.default.post(name: Notification.Name(rawValue: SKPHOTO_LOADING_DID_END_NOTIFICATION), object: self)
    }
}

// MARK: - Static Function

@available(iOS 9.1, *)
extension SKLivePhoto {
    public static func photoWithLivePhoto(_ livePhoto: PHLivePhoto) -> SKLivePhoto {
        return SKLivePhoto(livePhoto: livePhoto, image: nil)
    }
    
    public static func photoWithLivePhoto(_ livePhoto: PHLivePhoto, image: UIImage) -> SKLivePhoto {
        return SKLivePhoto(livePhoto: livePhoto, image: image)
    }
    
    public static func photoWithLivePhotoURL(_ url: URL) -> SKLivePhoto {
        return SKLivePhoto(livePhotoURL: url, image: nil)
    }
    
    public static func photoWithLivePhotoURL(_ url: URL, image: UIImage) -> SKLivePhoto {
        return SKLivePhoto(livePhotoURL: url, image: image)
    }
} 