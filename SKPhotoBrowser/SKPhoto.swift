//
//  SKPhoto.swift
//  SKViewExample
//
//  Created by suzuki_keishi on 2015/10/01.
//  Copyright © 2015 suzuki_keishi. All rights reserved.
//

import UIKit

@objc public protocol SKPhotoProtocol: NSObjectProtocol {
    var index: Int { get set }
    var underlyingImage: UIImage! { get }
    var caption: String? { get }
    var contentMode: UIView.ContentMode { get set }
    func loadUnderlyingImageAndNotify()
    func checkCache()
}

// MARK: - SKPhoto
open class SKPhoto: NSObject, SKPhotoProtocol {
    open var index: Int = 0
    open var underlyingImage: UIImage!
    open var caption: String?
    open var contentMode: UIView.ContentMode = .scaleAspectFill
    open var shouldCachePhotoURLImage: Bool = false
    open var photoURL: String!

    override init() {
        super.init()
    }
    
    convenience init(image: UIImage) {
        self.init()
        underlyingImage = image
    }
    
    convenience init(url: String) {
        self.init()
        photoURL = url
    }
    
    convenience init(url: String, holder: UIImage?) {
        self.init()
        photoURL = url
        underlyingImage = holder
    }
    
    open func checkCache() {
        guard let photoURL = photoURL else {
            return
        }
        guard shouldCachePhotoURLImage else {
            return
        }
        
        if SKCache.sharedCache.imageCache is SKRequestResponseCacheable {
            if let url = URL(string: photoURL), let img = SKCache.sharedCache.imageForRequest(URLRequest(url: url)) {
                underlyingImage = img
            }
        } else {
            if let img = SKCache.sharedCache.imageForKey(photoURL) {
                underlyingImage = img
            }
        }
    }
    
    open func loadUnderlyingImageAndNotify() {
        guard let photoURL = photoURL, let url = URL(string: photoURL) else { return }

        let request = URLRequest(url: url)
        let session = URLSession(configuration: SKPhotoBrowserOptions.sessionConfiguration)
        let task = session.dataTask(with: request, completionHandler: { [weak self] (data, response, error) in
            guard let self = self else { return }
            defer { session.finishTasksAndInvalidate() }

            guard error == nil else {
                DispatchQueue.main.async { self.loadUnderlyingImageComplete() }
                return
            }

            guard let data = data, let response = response else { return }
            let image: UIImage? = photoURL.lowercased().hasSuffix(".gif")
                ? UIImage.gif(data: data)
                : UIImage(data: data)
            if let image = image {
                if self.shouldCachePhotoURLImage {
                    if SKCache.sharedCache.imageCache is SKRequestResponseCacheable {
                        SKCache.sharedCache.setImageData(data, response: response, request: request)
                    } else {
                        if photoURL.lowercased().hasSuffix(".gif") {
                            SKCache.sharedCache.setData(data, forKey: photoURL)
                        } else {
                            SKCache.sharedCache.setImage(image, forKey: photoURL)
                        }
                    }
                }
                DispatchQueue.main.async {
                    self.underlyingImage = image
                    self.loadUnderlyingImageComplete()
                }
            } else {
                DispatchQueue.main.async { self.loadUnderlyingImageComplete() }
            }
        })
        task.resume()
    }

    open func loadUnderlyingImageComplete() {
        NotificationCenter.default.post(name: Notification.Name(rawValue: SKPHOTO_LOADING_DID_END_NOTIFICATION), object: self)
    }
    
}

// MARK: - Static Function

extension SKPhoto {
    public static func photoWithImage(_ image: UIImage) -> SKPhoto {
        return SKPhoto(image: image)
    }
    
    public static func photoWithImageURL(_ url: String) -> SKPhoto {
        return SKPhoto(url: url)
    }
    
    public static func photoWithImageURL(_ url: String, holder: UIImage?) -> SKPhoto {
        return SKPhoto(url: url, holder: holder)
    }
}
