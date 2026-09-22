//
//  SKPhotoBrowserTransition.swift
//  SKPhotoBrowser
//
//  Custom present/dismiss transition like ImagePreviewViewController (scale from origin view).
//

import UIKit

// MARK: - Frame Helpers (used by both animators)

private func calcOriginFrame(_ sender: UIView) -> CGRect {
    if let frame = sender.superview?.convert(sender.frame, to: nil) {
        return frame
    }
    return .zero
}

private func calcFinalFrame(imageRatio: CGFloat, in containerSize: CGSize) -> CGRect {
    guard !imageRatio.isNaN, containerSize.width > 0, containerSize.height > 0 else { return .zero }
    let screenRatio = containerSize.width / containerSize.height

    if screenRatio < imageRatio {
        let width = containerSize.width
        let height = width / imageRatio
        let yOffset = (containerSize.height - height) / 2
        return CGRect(x: 0, y: yOffset, width: width, height: height)
    } else if SKPhotoBrowserOptions.longPhotoWidthMatchScreen && imageRatio <= 1.0 {
        let height = containerSize.width / imageRatio
        return CGRect(x: 0, y: 0, width: containerSize.width, height: height)
    } else {
        let height = containerSize.height
        let width = height * imageRatio
        let xOffset = (containerSize.width - width) / 2
        return CGRect(x: xOffset, y: 0, width: width, height: height)
    }
}

/// Thumbnail image for dismiss morph — prefer the live cell image so it matches what reappears.
func sk_thumbnailImage(from sender: UIView?, browser: SKPhotoBrowser) -> UIImage? {
    if let imageView = sender as? UIImageView, let image = imageView.image {
        return image
    }
    if let sender = sender {
        return browser.getImageFromView(sender)
    }
    return browser.animator.senderOriginImage
}

/// Composite view used when dismissing back onto a thumbnail that is a different crop/image.
/// Bottom: thumbnail (aspectFill) · Top: full image — crossfade as the frame shrinks.
func sk_makeDismissTransitionView(
    fullContent: UIView,
    thumbnail: UIImage?,
    thumbnailContentMode: UIView.ContentMode,
    frame: CGRect
) -> (container: UIView, fullLayer: UIView, thumbLayer: UIImageView?) {
    let container = UIView(frame: frame)
    container.clipsToBounds = true
    container.backgroundColor = .clear

    var thumbLayer: UIImageView?
    if let thumbnail = thumbnail {
        let thumb = UIImageView(image: thumbnail)
        thumb.contentMode = thumbnailContentMode
        thumb.clipsToBounds = true
        thumb.frame = container.bounds
        thumb.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        thumb.alpha = 0
        container.addSubview(thumb)
        thumbLayer = thumb
    }

    fullContent.frame = container.bounds
    fullContent.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    container.addSubview(fullContent)

    return (container, fullContent, thumbLayer)
}

/// Present morph: start as the cell thumbnail (aspectFill), expand while revealing aspectFit.
func sk_makePresentTransitionView(
    thumbnail: UIImage,
    thumbnailContentMode: UIView.ContentMode,
    endImage: UIImage,
    endContentMode: UIView.ContentMode,
    frame: CGRect,
    cornerRadius: CGFloat
) -> (container: UIView, thumbLayer: UIImageView, endLayer: UIImageView) {
    let container = UIView(frame: frame)
    container.clipsToBounds = true
    container.backgroundColor = .clear
    container.layer.cornerRadius = cornerRadius

    let thumbLayer = UIImageView(image: thumbnail)
    thumbLayer.contentMode = thumbnailContentMode
    thumbLayer.clipsToBounds = true
    thumbLayer.frame = container.bounds
    thumbLayer.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    let endLayer = UIImageView(image: endImage)
    endLayer.contentMode = endContentMode
    endLayer.clipsToBounds = true
    endLayer.frame = container.bounds
    endLayer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    endLayer.alpha = 0

    container.addSubview(thumbLayer)
    container.addSubview(endLayer)
    return (container, thumbLayer, endLayer)
}

// MARK: - SKPhotoBrowserPresentAnimator

final class SKPhotoBrowserPresentAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        SKPhotoBrowserOptions.bounceAnimation ? 0.55 : 0.42
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toVC = transitionContext.viewController(forKey: .to) as? SKPhotoBrowser else {
            transitionContext.completeTransition(false)
            return
        }

        let containerView = transitionContext.containerView
        toVC.view.frame = transitionContext.finalFrame(for: toVC)
        containerView.addSubview(toVC.view)

        let originView = toVC.delegate?.viewForPhoto?(toVC, index: toVC.currentPageIndex) ?? toVC.animator.senderViewForAnimation
        guard let sender = originView else {
            toVC.view.alpha = 0
            UIView.animate(withDuration: 0.28, animations: {
                toVC.view.alpha = 1
            }, completion: { finished in
                transitionContext.completeTransition(finished)
                toVC.autoPlayLivePhotoIfNeeded(at: toVC.currentPageIndex)
            })
            return
        }

        toVC.animator.senderViewOriginalBackgroundColor = sender.backgroundColor
        // Hide the thumbnail while the zooming image covers it (avoids double-image).
        sender.alpha = 0

        toVC.view.alpha = 0
        toVC.view.layoutIfNeeded()

        let photo = toVC.photoAtIndex(toVC.currentPageIndex)
        let thumbImage = (toVC.animator.senderOriginImage ?? toVC.getImageFromView(sender)).rotateImageByOrientation()
        // Prefer a already-decoded full image when available so the expand lands on sharp pixels.
        let endImage = (photo.underlyingImage?.rotateImageByOrientation()).flatMap { full in
            (full.size.width >= thumbImage.size.width || full.size.height >= thumbImage.size.height) ? full : nil
        } ?? thumbImage
        let imageRatio = endImage.size.width / endImage.size.height
        let startFrame = calcOriginFrame(sender)
        let finalFrameInBrowser = calcFinalFrame(imageRatio: imageRatio, in: containerView.bounds.size)

        let thumbMode = (sender as? UIImageView)?.contentMode ?? .scaleAspectFill
        let built = sk_makePresentTransitionView(
            thumbnail: thumbImage,
            thumbnailContentMode: thumbMode,
            endImage: endImage,
            endContentMode: photo.contentMode,
            frame: startFrame,
            cornerRadius: sender.layer.cornerRadius
        )
        let transitionView = built.container
        let thumbLayer = built.thumbLayer
        let endLayer = built.endLayer
        containerView.addSubview(transitionView)

        if let page = toVC.pageDisplayedAtIndex(toVC.currentPageIndex) {
            page.imageView.isHidden = true
            if #available(iOS 9.1, *) {
                page.livePhotoView?.isHidden = true
            }
        }

        let duration = transitionDuration(using: transitionContext)
        let damping: CGFloat = SKPhotoBrowserOptions.bounceAnimation ? 0.82 : 0.92

        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: damping, initialSpringVelocity: 0.08, options: .curveEaseOut, animations: {
            toVC.showButtons()
            transitionView.frame = finalFrameInBrowser
            transitionView.layer.cornerRadius = 0
            // Expand while revealing aspectFit so the open handoff matches the browser,
            // even when the cell crop (aspectFill) differs from the full image.
            thumbLayer.alpha = 0
            endLayer.alpha = 1
            toVC.view.alpha = 1
        }, completion: { _ in
            transitionView.removeFromSuperview()
            // Browser now covers the thumbnail — restore so a later dismiss
            // to a different page never leaves this cell stuck invisible.
            sender.alpha = 1
            if let page = toVC.pageDisplayedAtIndex(toVC.currentPageIndex) {
                if page.livePhotoView == nil {
                    page.imageView.isHidden = false
                } else if #available(iOS 9.1, *) {
                    page.livePhotoView?.isHidden = false
                }
            }
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            toVC.autoPlayLivePhotoIfNeeded(at: toVC.currentPageIndex)
        })
    }
}

// MARK: - SKPhotoBrowserDismissAnimator

final class SKPhotoBrowserDismissAnimator: NSObject, UIViewControllerAnimatedTransitioning {

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromVC = transitionContext.viewController(forKey: .from) as? SKPhotoBrowser else {
            transitionContext.completeTransition(false)
            return
        }

        let containerView = transitionContext.containerView
        let duration = transitionDuration(using: transitionContext)

        var originView = fromVC.delegate?.viewForPhoto?(fromVC, index: fromVC.currentPageIndex)
        if originView == nil && fromVC.currentPageIndex == fromVC.initPageIndex {
            originView = fromVC.animator.senderViewForAnimation
        }

        guard let zoomingScrollView = fromVC.pageDisplayedAtIndex(fromVC.currentPageIndex) else {
            UIView.animate(withDuration: 0.28, delay: 0, options: .curveEaseOut, animations: {
                fromVC.view.alpha = 0
            }, completion: { finished in
                transitionContext.completeTransition(finished)
            })
            return
        }

        let mediaView: UIView
        if let livePhotoView = zoomingScrollView.livePhotoView {
            mediaView = livePhotoView
        } else {
            mediaView = zoomingScrollView.imageView
        }

        let frameInContainer = containerView.convert(mediaView.bounds, from: mediaView)
        let photo = fromVC.photoAtIndex(fromVC.currentPageIndex)
        let isLivePhoto: Bool = {
            if #available(iOS 9.1, *), photo is SKLivePhoto, zoomingScrollView.livePhotoView != nil {
                return true
            }
            return false
        }()

        // Prefer the decoded image for still photos (sharper than a snapshot).
        let fullContent: UIView
        if !isLivePhoto, let image = photo.underlyingImage {
            let imageView = UIImageView(image: image.rotateImageByOrientation())
            imageView.contentMode = mediaView.contentMode
            imageView.clipsToBounds = true
            fullContent = imageView
        } else if let snapshot = mediaView.snapshotView(afterScreenUpdates: false) {
            fullContent = snapshot
        } else if let image = photo.underlyingImage {
            let imageView = UIImageView(image: image.rotateImageByOrientation())
            imageView.contentMode = mediaView.contentMode
            imageView.clipsToBounds = true
            fullContent = imageView
        } else {
            UIView.animate(withDuration: 0.28, delay: 0, options: .curveEaseOut, animations: {
                fromVC.view.alpha = 0
            }, completion: { finished in
                transitionContext.completeTransition(finished)
            })
            return
        }

        let thumb = sk_thumbnailImage(from: originView, browser: fromVC)
        let thumbMode = (originView as? UIImageView)?.contentMode ?? .scaleAspectFill
        let built = sk_makeDismissTransitionView(
            fullContent: fullContent,
            thumbnail: thumb,
            thumbnailContentMode: thumbMode,
            frame: frameInContainer
        )
        let transitionView = built.container
        let fullLayer = built.fullLayer
        let thumbLayer = built.thumbLayer

        containerView.addSubview(transitionView)
        fromVC.view.alpha = 1
        mediaView.isHidden = true
        fromVC.pagingScrollView.alpha = 0

        // Keep the real thumbnail hidden until the morph lands on it.
        originView?.alpha = 0

        let targetFrame: CGRect?
        if let sender = originView {
            let frame = calcOriginFrame(sender)
            targetFrame = (frame.width > 1 && frame.height > 1) ? frame : nil
            let cornerRadius = sender.layer.cornerRadius
            if cornerRadius > 0 {
                transitionView.layer.masksToBounds = true
                transitionView.layer.cornerRadius = 0
                transitionView.addCornerRadiusAnimation(0, to: cornerRadius, duration: duration)
            }
        } else {
            targetFrame = nil
        }

        var didCompleteTransition = false
        let finishTransition = {
            guard !didCompleteTransition else { return }
            didCompleteTransition = true
            transitionView.removeFromSuperview()
            mediaView.isHidden = false
            fromVC.pagingScrollView.alpha = 1
            let restoredColor = fromVC.animator.senderViewOriginalBackgroundColor ?? .clear
            var restored = Set<ObjectIdentifier>()
            for origin in [
                fromVC.delegate?.viewForPhoto?(fromVC, index: fromVC.currentPageIndex),
                fromVC.animator.senderViewForAnimation,
                originView
            ].compactMap({ $0 }) {
                let id = ObjectIdentifier(origin)
                guard restored.insert(id).inserted else { continue }
                origin.alpha = 1
                origin.backgroundColor = restoredColor
            }
            fromVC.animator.senderViewOriginalBackgroundColor = nil
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.6) { finishTransition() }
        let cleanup = { DispatchQueue.main.async(execute: finishTransition) }

        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 0.88,
            initialSpringVelocity: 0.12,
            options: .curveEaseOut,
            animations: {
                fromVC.view.alpha = 0
                fromVC.view.backgroundColor = .clear
                if let targetFrame = targetFrame {
                    // Shrink onto the thumbnail while crossfading full → thumb
                    // so the handoff matches the cell (different crop / resolution).
                    transitionView.frame = targetFrame
                    if thumbLayer != nil {
                        fullLayer.alpha = 0
                        thumbLayer?.alpha = 1
                    }
                } else {
                    // No thumbnail anchor — still animate a dismiss for normal photos.
                    let frame = transitionView.frame
                    let scale: CGFloat = 0.82
                    let newSize = CGSize(width: frame.width * scale, height: frame.height * scale)
                    transitionView.frame = CGRect(
                        x: frame.midX - newSize.width / 2,
                        y: frame.midY - newSize.height / 2 + containerView.bounds.height * 0.12,
                        width: newSize.width,
                        height: newSize.height
                    )
                    transitionView.alpha = 0
                }
            },
            completion: { _ in cleanup() }
        )
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        SKPhotoBrowserOptions.bounceAnimation ? 0.55 : 0.42
    }

}
