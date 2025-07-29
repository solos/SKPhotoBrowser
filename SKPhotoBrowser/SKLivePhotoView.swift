//
//  SKLivePhotoView.swift
//  SKPhotoBrowser
//
//  Created by SKPhotoBrowser on 2024/01/01.
//  Copyright © 2024 SKPhotoBrowser. All rights reserved.
//

import UIKit
import PhotosUI

@available(iOS 9.1, *)
open class SKLivePhotoView: UIView {
    private var livePhotoView: PHLivePhotoView!
    private var imageView: UIImageView!
    private var isLivePhotoAvailable: Bool = false
    private var isCurrentlyPlaying: Bool = false
    
    public var livePhoto: PHLivePhoto? {
        didSet {
            updateLivePhoto()
        }
    }
    
    public var image: UIImage? {
        didSet {
            updateImage()
        }
    }
    
    public override var contentMode: UIView.ContentMode {
        get {
            return super.contentMode
        }
        set {
            super.contentMode = newValue
            imageView.contentMode = newValue
            livePhotoView.contentMode = newValue
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        backgroundColor = .clear
        
        // Set default content mode
        contentMode = .scaleAspectFill
        
        // Setup image view as fallback
        imageView = UIImageView()
        imageView.contentMode = contentMode
        imageView.backgroundColor = .clear
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        
        // Setup live photo view
        livePhotoView = PHLivePhotoView()
        livePhotoView.contentMode = contentMode
        livePhotoView.backgroundColor = .clear
        livePhotoView.translatesAutoresizingMaskIntoConstraints = false
        livePhotoView.isHidden = true
        addSubview(livePhotoView)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            livePhotoView.topAnchor.constraint(equalTo: topAnchor),
            livePhotoView.leadingAnchor.constraint(equalTo: leadingAnchor),
            livePhotoView.trailingAnchor.constraint(equalTo: trailingAnchor),
            livePhotoView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    private func updateLivePhoto() {
        guard let livePhoto = livePhoto else {
            livePhotoView.isHidden = true
            imageView.isHidden = false
            return
        }
        
        livePhotoView.livePhoto = livePhoto
        livePhotoView.isHidden = false
        imageView.isHidden = true
        isLivePhotoAvailable = true
    }
    
    private func updateImage() {
        guard let image = image else {
            imageView.image = nil
            return
        }
        
        imageView.image = image
        if !isLivePhotoAvailable {
            imageView.isHidden = false
            livePhotoView.isHidden = true
        }
    }
    
    // MARK: - Public Methods
    
    public func startPlayback() {
        guard isLivePhotoAvailable else { return }
        livePhotoView.startPlayback(with: .hint)
        isCurrentlyPlaying = true
    }
    
    public func stopPlayback() {
        guard isLivePhotoAvailable else { return }
        livePhotoView.stopPlayback()
        isCurrentlyPlaying = false
    }
    
    public func isPlaying() -> Bool {
        guard isLivePhotoAvailable else { return false }
        return isCurrentlyPlaying
    }
}

// MARK: - SKDetectingViewDelegate

@available(iOS 9.1, *)
extension SKLivePhotoView: SKDetectingViewDelegate {
    public func handleSingleTap(_ view: UIView, touch: UITouch) {
        // Handle single tap for Live Photo playback
        if isLivePhotoAvailable {
            if isPlaying() {
                stopPlayback()
            } else {
                startPlayback()
            }
        }
    }
    
    public func handleDoubleTap(_ view: UIView, touch: UITouch) {
        // Handle double tap for zoom (if needed)
    }
} 
