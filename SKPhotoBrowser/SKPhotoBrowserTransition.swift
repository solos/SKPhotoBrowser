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

// MARK: - SKPhotoBrowserPresentAnimator

final class SKPhotoBrowserPresentAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        SKPhotoBrowserOptions.bounceAnimation ? 0.5 : 0.35
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
            UIView.animate(withDuration: 0.25, animations: {
                toVC.view.alpha = 1
            }, completion: { finished in
                transitionContext.completeTransition(finished)
            })
            return
        }

        toVC.animator.senderViewOriginalBackgroundColor = sender.backgroundColor
        sender.backgroundColor = UIColor(white: 0.92, alpha: 1)

        toVC.view.alpha = 0
        toVC.view.layoutIfNeeded()

        let photo = toVC.photoAtIndex(toVC.currentPageIndex)
        let imageFromView = (toVC.animator.senderOriginImage ?? toVC.getImageFromView(sender)).rotateImageByOrientation()
        let imageRatio = imageFromView.size.width / imageFromView.size.height
        let startFrame = calcOriginFrame(sender)
        let finalFrameInBrowser = calcFinalFrame(imageRatio: imageRatio, in: containerView.bounds.size)

        let resizableImageView = UIImageView(image: imageFromView)
        resizableImageView.frame = startFrame
        resizableImageView.clipsToBounds = true
        resizableImageView.contentMode = photo.contentMode
        containerView.addSubview(resizableImageView)

        if let page = toVC.pageDisplayedAtIndex(toVC.currentPageIndex) {
            page.imageView.isHidden = true
        }

        let duration = transitionDuration(using: transitionContext)
        let damping: CGFloat = SKPhotoBrowserOptions.bounceAnimation ? 0.8 : 1.0

        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: damping, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
            toVC.showButtons()
            resizableImageView.frame = finalFrameInBrowser
            toVC.view.alpha = 1
        }, completion: { finished in
            resizableImageView.removeFromSuperview()
            toVC.pageDisplayedAtIndex(toVC.currentPageIndex)?.imageView.isHidden = false
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        })
    }
}

// MARK: - SKPhotoBrowserDismissAnimator

final class SKPhotoBrowserDismissAnimator: NSObject, UIViewControllerAnimatedTransitioning {

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        // ✅ 关键修复：如果是交互式转场，直接完成，不执行动画
        if transitionContext.isInteractive {
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            return
        }

        // ... 以下是原有非交互式关闭逻辑（保持不变）...
        guard let fromVC = transitionContext.viewController(forKey: .from) as? SKPhotoBrowser else {
            transitionContext.completeTransition(false)
            return
        }

        let containerView = transitionContext.containerView
        let originView = fromVC.delegate?.viewForPhoto?(fromVC, index: fromVC.currentPageIndex) ?? fromVC.animator.senderViewForAnimation

        guard let sender = originView, let zoomingScrollView = fromVC.pageDisplayedAtIndex(fromVC.currentPageIndex) else {
            UIView.animate(withDuration: 0.28, delay: 0, options: .curveEaseOut, animations: {
                fromVC.view.alpha = 0
            }, completion: { finished in
                transitionContext.completeTransition(finished)
            })
            return
        }

        let finalFrame = calcOriginFrame(sender)
        let transitionView: UIView

        let frameInContainer = containerView.convert(zoomingScrollView.frame, from: zoomingScrollView.superview)
        if let snapshot = zoomingScrollView.snapshotView(afterScreenUpdates: false) {
            transitionView = snapshot
            transitionView.frame = frameInContainer
        } else if let image = fromVC.photoAtIndex(fromVC.currentPageIndex).underlyingImage {
            let imageView = UIImageView(image: image.rotateImageByOrientation())
            imageView.contentMode = zoomingScrollView.imageView.contentMode
            imageView.clipsToBounds = true
            imageView.frame = frameInContainer
            transitionView = imageView
        } else {
            transitionContext.completeTransition(true)
            return
        }

        containerView.addSubview(transitionView)
        fromVC.view.alpha = 1
        zoomingScrollView.isHidden = true

        let duration = transitionDuration(using: transitionContext)
        let targetCornerRadius = sender.layer.cornerRadius
        if targetCornerRadius > 0 {
            transitionView.layer.masksToBounds = true
            transitionView.layer.cornerRadius = 0
            transitionView.addCornerRadiusAnimation(0, to: targetCornerRadius, duration: duration)
        }

        let scaleEnd: CGFloat = 0.92
        transitionView.transform = .identity

        var didCompleteTransition = false
        let finishTransition = {
            guard !didCompleteTransition else { return }
            didCompleteTransition = true
            transitionView.removeFromSuperview()
            transitionView.transform = .identity
            zoomingScrollView.isHidden = false
            if let origin = fromVC.delegate?.viewForPhoto?(fromVC, index: fromVC.currentPageIndex) ?? fromVC.animator.senderViewForAnimation {
                origin.backgroundColor = fromVC.animator.senderViewOriginalBackgroundColor ?? .clear
            }
            fromVC.animator.senderViewOriginalBackgroundColor = nil
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }

        let maxWait = duration + 0.6
        DispatchQueue.main.asyncAfter(deadline: .now() + maxWait) { finishTransition() }

        let cleanup = { DispatchQueue.main.async(execute: finishTransition) }

        if SKPhotoBrowserOptions.bounceAnimation {
            let damping: CGFloat = 0.86
            UIView.animate(withDuration: duration * 0.75, delay: 0, options: .curveEaseIn, animations: {
                fromVC.view.alpha = 0
            })
            UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: damping, initialSpringVelocity: 0.2, options: .curveEaseOut, animations: {
                transitionView.frame = finalFrame
                transitionView.transform = CGAffineTransform(scaleX: scaleEnd, y: scaleEnd)
            }, completion: { _ in cleanup() })
        } else {
            UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
                fromVC.view.alpha = 0
                transitionView.frame = finalFrame
                transitionView.transform = CGAffineTransform(scaleX: scaleEnd, y: scaleEnd)
            }, completion: { _ in cleanup() })
        }
    }

    unc transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        SKPhotoBrowserOptions.bounceAnimation ? 0.65 : 0.52
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        // ✅ 关键修复：如果是交互式转场，直接完成，不执行动画
        if transitionContext.isInteractive {
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            return
        }

        // ... 以下是原有非交互式关闭逻辑（保持不变）...
        guard let fromVC = transitionContext.viewController(forKey: .from) as? SKPhotoBrowser else {
            transitionContext.completeTransition(false)
            return
        }

        let containerView = transitionContext.containerView
        let originView = fromVC.delegate?.viewForPhoto?(fromVC, index: fromVC.currentPageIndex) ?? fromVC.animator.senderViewForAnimation

        guard let sender = originView, let zoomingScrollView = fromVC.pageDisplayedAtIndex(fromVC.currentPageIndex) else {
            UIView.animate(withDuration: 0.28, delay: 0, options: .curveEaseOut, animations: {
                fromVC.view.alpha = 0
            }, completion: { finished in
                transitionContext.completeTransition(finished)
            })
            return
        }

        let finalFrame = calcOriginFrame(sender)
        let transitionView: UIView

        let frameInContainer = containerView.convert(zoomingScrollView.frame, from: zoomingScrollView.superview)
        if let snapshot = zoomingScrollView.snapshotView(afterScreenUpdates: false) {
            transitionView = snapshot
            transitionView.frame = frameInContainer
        } else if let image = fromVC.photoAtIndex(fromVC.currentPageIndex).underlyingImage {
            let imageView = UIImageView(image: image.rotateImageByOrientation())
            imageView.contentMode = zoomingScrollView.imageView.contentMode
            imageView.clipsToBounds = true
            imageView.frame = frameInContainer
            transitionView = imageView
        } else {
            transitionContext.completeTransition(true)
            return
        }

        containerView.addSubview(transitionView)
        fromVC.view.alpha = 1
        zoomingScrollView.isHidden = true

        let duration = transitionDuration(using: transitionContext)
        let targetCornerRadius = sender.layer.cornerRadius
        if targetCornerRadius > 0 {
            transitionView.layer.masksToBounds = true
            transitionView.layer.cornerRadius = 0
            transitionView.addCornerRadiusAnimation(0, to: targetCornerRadius, duration: duration)
        }

        let scaleEnd: CGFloat = 0.92
        transitionView.transform = .identity

        var didCompleteTransition = false
        let finishTransition = {
            guard !didCompleteTransition else { return }
            didCompleteTransition = true
            transitionView.removeFromSuperview()
            transitionView.transform = .identity
            zoomingScrollView.isHidden = false
            if let origin = fromVC.delegate?.viewForPhoto?(fromVC, index: fromVC.currentPageIndex) ?? fromVC.animator.senderViewForAnimation {
                origin.backgroundColor = fromVC.animator.senderViewOriginalBackgroundColor ?? .clear
            }
            fromVC.animator.senderViewOriginalBackgroundColor = nil
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }

        let maxWait = duration + 0.6
        DispatchQueue.main.asyncAfter(deadline: .now() + maxWait) { finishTransition() }

        let cleanup = { DispatchQueue.main.async(execute: finishTransition) }

        if SKPhotoBrowserOptions.bounceAnimation {
            let damping: CGFloat = 0.86
            UIView.animate(withDuration: duration * 0.75, delay: 0, options: .curveEaseIn, animations: {
                fromVC.view.alpha = 0
            })
            UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: damping, initialSpringVelocity: 0.2, options: .curveEaseOut, animations: {
                transitionView.frame = finalFrame
                transitionView.transform = CGAffineTransform(scaleX: scaleEnd, y: scaleEnd)
            }, completion: { _ in cleanup() })
        } else {
            UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
                fromVC.view.alpha = 0
                transitionView.frame = finalFrame
                transitionView.transform = CGAffineTransform(scaleX: scaleEnd, y: scaleEnd)
            }, completion: { _ in cleanup() })
        }
    }
}
