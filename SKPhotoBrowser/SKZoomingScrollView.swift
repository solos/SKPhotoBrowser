//
//  SKZoomingScrollView.swift
//  SKViewExample
//
//  Created by suzuki_keihsi on 2015/10/01.
//  Copyright © 2015 suzuki_keishi. All rights reserved.
//

import UIKit
import Photos
import PhotosUI

open class SKZoomingScrollView: UIScrollView {
    var captionView: SKCaptionView!
    var photo: SKPhotoProtocol! {
        didSet {
            imageView.image = nil
            guard let photo = photo else { return }

            // Live Photo: even with a still placeholder, keep loading until PHLivePhoto is ready.
            if #available(iOS 9.1, *), let live = photo as? SKLivePhoto {
                displayImage(complete: live.livePhoto != nil)
                return
            }

            if photo.underlyingImage != nil {
                // Remote photos may start with a thumbnail holder; keep loading until the URL resolves.
                if let remote = photo as? SKPhoto,
                   let url = remote.photoURL,
                   !url.isEmpty,
                   !remote.remoteImageLoaded {
                    displayImage(complete: false)
                    return
                }
                displayImage(complete: true)
                return
            }
            displayImage(complete: false)
        }
    }
    
    fileprivate weak var browser: SKPhotoBrowser?
    
    fileprivate(set) var imageView: SKDetectingImageView!
    fileprivate var tapView: SKDetectingView!
    fileprivate var indicatorView: SKIndicatorView!
    /// Sibling of imageView, never the view returned by viewForZooming.
    /// UIScrollView applies a transform to the zoom view; PHLivePhotoView will not play under that transform.
    fileprivate(set) var livePhotoView: UIView?
    /// Whether the currently displayed Live Photo should be playing.
    /// Set by playLivePhoto()/stopLivePhoto(); used to loop playback and retry
    /// when the view becomes visible (e.g. after the present transition).
    var wantsLivePhotoPlayback = false
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    convenience init(frame: CGRect, browser: SKPhotoBrowser) {
        self.init(frame: frame)
        self.browser = browser
    }
    
    deinit {
        browser = nil
    }
    
    func setup() {
        // tap
        tapView = SKDetectingView(frame: bounds)
        tapView.delegate = self
        tapView.backgroundColor = .clear
        tapView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        addSubview(tapView)
        
        // image
        imageView = SKDetectingImageView(frame: frame)
        imageView.delegate = self
        imageView.contentMode = .bottom
        imageView.backgroundColor = .clear
        addSubview(imageView)
        
        // indicator
        indicatorView = SKIndicatorView(frame: frame)
        addSubview(indicatorView)
        
        // self
        backgroundColor = .clear
        delegate = self
        showsHorizontalScrollIndicator = SKPhotoBrowserOptions.displayHorizontalScrollIndicator
        showsVerticalScrollIndicator = SKPhotoBrowserOptions.displayVerticalScrollIndicator
        autoresizingMask = [.flexibleWidth, .flexibleTopMargin, .flexibleBottomMargin, .flexibleRightMargin, .flexibleLeftMargin]
    }
    
    // MARK: - override
    
    open override func layoutSubviews() {
        tapView.frame = bounds
        indicatorView.frame = bounds
        
        super.layoutSubviews()
        
        let boundsSize = bounds.size
        // Always center the image view. The Live Photo view copies its frame afterwards
        // so it is positioned the same way without becoming the zooming view.
        let activeView: UIView = imageView
        var frameToCenter = activeView.frame
        
        // horizon
        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = floor((boundsSize.width - frameToCenter.size.width) / 2)
        } else {
            frameToCenter.origin.x = 0
        }
        // vertical
        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = floor((boundsSize.height - frameToCenter.size.height) / 2)
        } else {
            frameToCenter.origin.y = 0
        }
        
        // Center
        if !activeView.frame.equalTo(frameToCenter) {
            activeView.frame = frameToCenter
        }
        syncLivePhotoFrame()
    }
    
    open func setMaxMinZoomScalesForCurrentBounds() {
        maximumZoomScale = 1
        minimumZoomScale = 1
        zoomScale = 1
        
        let activeView: UIView = imageView
        guard activeView.frame.size != .zero else {
            return
        }
        
        let boundsSize = bounds.size
        let imageSize = activeView.frame.size
        
        let xScale = boundsSize.width / imageSize.width
        let yScale = boundsSize.height / imageSize.height
        var minScale: CGFloat = min(xScale.isNormal ? xScale : 1.0 , yScale.isNormal ? yScale : 1.0)
        var maxScale: CGFloat = 1.0
        
        let scale = max(SKMesurement.screenScale, 2.0)
        let deviceScreenWidth = SKMesurement.screenWidth * scale // width in pixels. scale needs to remove if to use the old algorithm
        let deviceScreenHeight = SKMesurement.screenHeight * scale // height in pixels. scale needs to remove if to use the old algorithm
        
        if SKPhotoBrowserOptions.longPhotoWidthMatchScreen && imageView.frame.height >= imageView.frame.width {
            minScale = 1.0
            maxScale = 2.5
        } else if imageView.frame.width < deviceScreenWidth {
            // I think that we should to get coefficient between device screen width and image width and assign it to maxScale. I made two mode that we will get the same result for different device orientations.
            let isPortrait = bounds.size.height >= bounds.size.width
            if isPortrait {
                maxScale = deviceScreenHeight / imageView.frame.width
            } else {
                maxScale = deviceScreenWidth / imageView.frame.width
            }
        } else if imageView.frame.width > deviceScreenWidth {
            maxScale = 1.0
        } else {
            // here if imageView.frame.width == deviceScreenWidth
            maxScale = 2.5
        }
    
        maximumZoomScale = maxScale
        minimumZoomScale = minScale
        zoomScale = minScale
        
        // on high resolution screens we have double the pixel density, so we will be seeing every pixel if we limit the
        // maximum zoom scale to 0.5
        // After changing this value, we still never use more
        /*
        maxScale = maxScale / scale 
        if maxScale < minScale {
            maxScale = minScale * 2
        }
        */
        
        // reset position
        imageView.frame.origin = CGPoint.zero
        setNeedsLayout()
    }
    
    open func prepareForReuse() {
        photo = nil
        if captionView != nil {
            captionView.removeFromSuperview()
            captionView = nil
        }
        if #available(iOS 9.1, *) {
            stopLivePhoto()
            if let lpv = livePhotoView as? PHLivePhotoView {
                lpv.delegate = nil
                lpv.livePhoto = nil
            }
        }
        livePhotoView?.removeFromSuperview()
        livePhotoView = nil
        imageView.isHidden = false
    }

    /// Match the still image's on-screen frame. Frame (not a zoom transform) keeps playback working.
    private func syncLivePhotoFrame() {
        guard let livePhotoView = livePhotoView else { return }
        let target = imageView.frame
        guard target.width > 0, target.height > 0, !livePhotoView.frame.equalTo(target) else { return }
        livePhotoView.frame = target
    }
    
    open override func didMoveToWindow() {
        super.didMoveToWindow()
        // startPlayback silently fails when the view is not yet in a window
        // (e.g. it was requested during the present transition). Retry as soon
        // as the page actually joins the window hierarchy.
        guard window != nil else { return }
        guard SKPhotoBrowserOptions.autoPlayLivePhoto, wantsLivePhotoPlayback else { return }
        if #available(iOS 9.1, *) {
            playLivePhoto()
        }
    }
    
    @available(iOS 9.1, *)
    open func displayLivePhoto(_ livePhoto: PHLivePhoto) {
        indicatorView.stopAnimating()

        // Use underlyingImage.size for consistency with displayImage; fall back to livePhoto.size
        let baseSize: CGSize = photo?.underlyingImage?.size ?? livePhoto.size
        var frameSize = baseSize
        if SKPhotoBrowserOptions.longPhotoWidthMatchScreen && baseSize.height >= baseSize.width, baseSize.width > 0 {
            let imageHeight = SKMesurement.screenWidth / baseSize.width * baseSize.height
            frameSize = CGSize(width: SKMesurement.screenWidth, height: imageHeight)
        }
        let livePhotoFrame = CGRect(origin: .zero, size: frameSize)

        // Keep imageView frame in sync so zoom calculations stay correct
        imageView.frame = livePhotoFrame
        imageView.isHidden = true

        let contentMode = photo?.contentMode ?? .scaleAspectFit
        if livePhotoView == nil {
            let lpv = PHLivePhotoView(frame: livePhotoFrame)
            lpv.contentMode = contentMode
            lpv.backgroundColor = .clear
            insertSubview(lpv, aboveSubview: imageView)
            livePhotoView = lpv
        } else {
            livePhotoView?.contentMode = contentMode
        }
        if let lpv = livePhotoView as? PHLivePhotoView {
            lpv.delegate = self
            lpv.livePhoto = livePhoto
        }

        contentSize = frameSize
        setMaxMinZoomScalesForCurrentBounds()
        syncLivePhotoFrame()
        setNeedsLayout()

        // Auto-play once the Live Photo is on screen (covers async load after viewDidAppear).
        if SKPhotoBrowserOptions.autoPlayLivePhoto,
           let browser = browser,
           browser.pageDisplayedAtIndex(browser.currentPageIndex) === self {
            playLivePhoto()
        }
    }

    /// Start Live Photo playback (with audio) and keep it looping.
    @available(iOS 9.1, *)
    open func playLivePhoto() {
        wantsLivePhotoPlayback = true
        guard let lpv = livePhotoView as? PHLivePhotoView, lpv.livePhoto != nil else { return }
        // startPlayback is unreliable before the view is in a window and laid out
        // (e.g. during present transition while browser.view is still fading in).
        // didMoveToWindow retries in that case.
        DispatchQueue.main.async { [weak self, weak lpv] in
            guard let self = self, let lpv = lpv else { return }
            guard self.wantsLivePhotoPlayback, lpv.livePhoto != nil else { return }
            guard lpv.window != nil, !lpv.isHidden else { return }
            lpv.startPlayback(with: .full)
        }
    }

    /// Stop Live Photo playback.
    @available(iOS 9.1, *)
    open func stopLivePhoto() {
        wantsLivePhotoPlayback = false
        (livePhotoView as? PHLivePhotoView)?.stopPlayback()
    }

    open func displayImage(_ image: UIImage) {
        // image
        imageView.image = image
        imageView.contentMode = photo.contentMode
        if livePhotoView == nil {
            imageView.isHidden = false
        }
        
        var imageViewFrame: CGRect = .zero
        imageViewFrame.origin = .zero
        // long photo
        if SKPhotoBrowserOptions.longPhotoWidthMatchScreen && image.size.height >= image.size.width {
            let imageHeight = SKMesurement.screenWidth / image.size.width * image.size.height
            imageViewFrame.size = CGSize(width: SKMesurement.screenWidth, height: imageHeight)
        } else {
            imageViewFrame.size = image.size
        }
        imageView.frame = imageViewFrame
        
        contentSize = imageViewFrame.size
        setMaxMinZoomScalesForCurrentBounds()
    }
    
    // MARK: - image
    open func displayImage(complete flag: Bool) {
        // reset scale
        maximumZoomScale = 1
        minimumZoomScale = 1
        zoomScale = 1
        
        if !flag {
            if photo.underlyingImage == nil {
                indicatorView.startAnimating()
            }
            photo.loadUnderlyingImageAndNotify()
        } else {
            indicatorView.stopAnimating()
        }
        
        if #available(iOS 9.1, *), let livePhoto = photo as? SKLivePhoto {
            if let phpLivePhoto = livePhoto.livePhoto {
                displayLivePhoto(phpLivePhoto)
            } else if let image = livePhoto.underlyingImage {
                displayImage(image)
            } else {
                contentSize = CGSize.zero
            }
        } else if let image = photo.underlyingImage, photo != nil {
            displayImage(image)
        } else {
            // change contentSize will reset contentOffset, so only set the contentsize zero when the image is nil
            contentSize = CGSize.zero
        }
        setNeedsLayout()
    }
    
    open func displayImageFailure() {
        indicatorView.stopAnimating()
    }
    
    // MARK: - handle tap
    open func handleDoubleTap(_ touchPoint: CGPoint) {
        if let browser = browser {
            NSObject.cancelPreviousPerformRequests(withTarget: browser)
        }
        
        if zoomScale > minimumZoomScale {
            // zoom out
            setZoomScale(minimumZoomScale, animated: true)
        } else {
            // zoom in
            // I think that the result should be the same after double touch or pinch
           /* var newZoom: CGFloat = zoomScale * 3.13
            if newZoom >= maximumZoomScale {
                newZoom = maximumZoomScale
            }
            */
            let zoomRect = zoomRectForScrollViewWith(maximumZoomScale, touchPoint: touchPoint)
            zoom(to: zoomRect, animated: true)
        }
        
        // delay control
        browser?.hideControlsAfterDelay()
    }
}

// MARK: - UIScrollViewDelegate

extension SKZoomingScrollView: UIScrollViewDelegate {
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        // PHLivePhotoView must not be the zoom view: UIScrollView's transform stops playback.
        return imageView
    }
    
    public func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        browser?.cancelControlHiding()
    }
    
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        syncLivePhotoFrame()
        setNeedsLayout()
        layoutIfNeeded()
    }
}

// MARK: - SKDetectingImageViewDelegate

extension SKZoomingScrollView: SKDetectingViewDelegate {
    func handleSingleTap(_ view: UIView, touch: UITouch) {
        guard let browser = browser else {
            return
        }
        guard SKPhotoBrowserOptions.enableZoomBlackArea == true else {
            return
        }
        
        if browser.areControlsHidden() == false && SKPhotoBrowserOptions.enableSingleTapDismiss == true {
            browser.determineAndClose()
        } else {
            browser.toggleControls()
        }
    }
    
    func handleDoubleTap(_ view: UIView, touch: UITouch) {
        if SKPhotoBrowserOptions.enableZoomBlackArea == true {
            let needPoint = getViewFramePercent(view, touch: touch)
            handleDoubleTap(needPoint)
        }
    }
}

// MARK: - SKDetectingImageViewDelegate

extension SKZoomingScrollView: SKDetectingImageViewDelegate {
    func handleImageViewSingleTap(_ touchPoint: CGPoint) {
        guard let browser = browser else {
            return
        }
        if SKPhotoBrowserOptions.enableSingleTapDismiss {
            browser.determineAndClose()
        } else {
            browser.toggleControls()
        }
    }
    
    func handleImageViewDoubleTap(_ touchPoint: CGPoint) {
        handleDoubleTap(touchPoint)
    }
}

// MARK: - PHLivePhotoViewDelegate

@available(iOS 9.1, *)
extension SKZoomingScrollView: PHLivePhotoViewDelegate {
    /// Playback reaches the end (or was stopped). Restart it while the page
    /// still wants playback so the Live Photo loops like the Photos app does
    /// while pressed. This also recovers from a startPlayback that ended
    /// immediately (e.g. it was triggered too early during a transition).
    public func livePhotoView(_ livePhotoView: PHLivePhotoView, didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
        guard SKPhotoBrowserOptions.autoPlayLivePhoto,
              wantsLivePhotoPlayback,
              livePhotoView.livePhoto != nil,
              livePhotoView.window != nil,
              !livePhotoView.isHidden else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self, weak livePhotoView] in
            guard let self = self, let lpv = livePhotoView else { return }
            guard self.wantsLivePhotoPlayback, lpv.livePhoto != nil,
                  lpv.window != nil, !lpv.isHidden else { return }
            lpv.startPlayback(with: .full)
        }
    }
}

private extension SKZoomingScrollView {
    func getViewFramePercent(_ view: UIView, touch: UITouch) -> CGPoint {
        let oneWidthViewPercent = view.bounds.width / 100
        let viewTouchPoint = touch.location(in: view)
        let viewWidthTouch = viewTouchPoint.x
        let viewPercentTouch = viewWidthTouch / oneWidthViewPercent
        let photoWidth = imageView.bounds.width
        let onePhotoPercent = photoWidth / 100
        let needPoint = viewPercentTouch * onePhotoPercent
        
        var Y: CGFloat!
        
        if viewTouchPoint.y < view.bounds.height / 2 {
            Y = 0
        } else {
            Y = imageView.bounds.height
        }
        let allPoint = CGPoint(x: needPoint, y: Y)
        return allPoint
    }
    
    func zoomRectForScrollViewWith(_ scale: CGFloat, touchPoint: CGPoint) -> CGRect {
        let w = frame.size.width / scale
        let h = frame.size.height / scale
        let x = touchPoint.x - (h / max(SKMesurement.screenScale, 2.0))
        let y = touchPoint.y - (w / max(SKMesurement.screenScale, 2.0))
        
        return CGRect(x: x, y: y, width: w, height: h)
    }
}
