//
//  SKPhotoBrowser.swift
//  SKViewExample
//
//  Created by suzuki_keishi on 2015/10/01.
//  Copyright © 2015 suzuki_keishi. All rights reserved.
//

import UIKit
import Photos

public let SKPHOTO_LOADING_DID_END_NOTIFICATION = "photoLoadingDidEndNotification"


// MARK: - SKPhotoBrowser
open class SKPhotoBrowser: UIViewController {
    // open function
    // MARK: - Interactive Dismiss Support
    private var interactiveDismissSnapshot: UIView?
    private var interactiveDismissOriginFrame: CGRect = .zero
    open var currentPageIndex: Int = 0
    open var initPageIndex: Int = 0
    open var activityItemProvider: UIActivityItemProvider?
    open var photos: [SKPhotoProtocol] = []
    
    internal lazy var pagingScrollView: SKPagingScrollView = SKPagingScrollView(frame: self.view.frame, browser: self)
    
    // appearance
    fileprivate let bgColor: UIColor = SKPhotoBrowserOptions.backgroundColor
    // animation
    let animator: SKAnimator = .init()
    
    // child component
    fileprivate var actionView: SKActionView!
    fileprivate(set) var paginationView: SKPaginationView!
    var toolbar: SKToolbar!
    
    // actions
    fileprivate var activityViewController: UIActivityViewController!
    internal var panGesture: UIPanGestureRecognizer?
    fileprivate var longPressGesture: UILongPressGestureRecognizer?
    /// Interactive dismiss (UIPercentDrivenInteractiveTransition), nil when not dragging to close.
    fileprivate var dismissInteractionController: UIPercentDrivenInteractiveTransition?
    fileprivate var isInteractivelyDismissing: Bool = false
    
    // for status check property
    fileprivate var isEndAnimationByToolBar: Bool = true
    fileprivate var isViewActive: Bool = false
    fileprivate var isPerformingLayout: Bool = false
    
    // timer
    fileprivate var controlVisibilityTimer: Timer!
    
    // delegate
    open weak var delegate: SKPhotoBrowserDelegate?
    
    // statusbar initial state
    private var statusbarHidden: Bool = UIApplication.shared.isStatusBarHidden
    
    // strings
    open var cancelTitle = "Cancel"
    
    // MARK: - Initializer
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    public override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: Bundle!) {
        super.init(nibName: nil, bundle: nil)
        setup()
    }
    
    public convenience init(photos: [SKPhotoProtocol]) {
        self.init(photos: photos, initialPageIndex: 0)
    }
    
    @available(*, deprecated)
    public convenience init(originImage: UIImage, photos: [SKPhotoProtocol], animatedFromView: UIView) {
        self.init(nibName: nil, bundle: nil)
        self.photos = photos
        self.photos.forEach { $0.checkCache() }
        animator.senderOriginImage = originImage
        animator.senderViewForAnimation = animatedFromView
    }
    
    public convenience init(photos: [SKPhotoProtocol], initialPageIndex: Int) {
        self.init(nibName: nil, bundle: nil)
        self.photos = photos
        self.photos.forEach { $0.checkCache() }
        self.currentPageIndex = min(initialPageIndex, photos.count - 1)
        self.initPageIndex = self.currentPageIndex
        animator.senderOriginImage = photos[currentPageIndex].underlyingImage
        animator.senderViewForAnimation = photos[currentPageIndex] as? UIView
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }


    private func calcOriginFrame(_ sender: UIView) -> CGRect {
        if let window = view.window {
            return sender.convert(sender.bounds, to: window)
        }
        return sender.frame
    }
    
    func setup() {
        modalPresentationCapturesStatusBarAppearance = true
        transitioningDelegate = self
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleSKPhotoLoadingDidEndNotification(_:)),
                                               name: NSNotification.Name(rawValue: SKPHOTO_LOADING_DID_END_NOTIFICATION),
                                               object: nil)
    }
    
    // MARK: - override
    override open func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
        configurePagingScrollView()
        configureGestureControl()
        configureActionView()
        configurePaginationView()
        configureToolbar()
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        reloadData()
        
        var i = 0
        for photo: SKPhotoProtocol in photos {
            photo.index = i
            i += 1
        }
    }
    
    override open func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        isPerformingLayout = true
        // where did start
        delegate?.didShowPhotoAtIndex?(self, index: currentPageIndex)
        
        // toolbar
        toolbar.frame = frameForToolbarAtOrientation()
        
        // action
        actionView.updateFrame(frame: view.frame)
        
        // paging
        switch SKCaptionOptions.captionLocation {
            case .basic:
                paginationView.updateFrame(frame: view.frame)
            case .bottom:
                paginationView.frame = frameForPaginationAtOrientation()
        }
        pagingScrollView.updateFrame(view.bounds, currentPageIndex: currentPageIndex)
        
        isPerformingLayout = false
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        isViewActive = true
    }
    
    override open var prefersStatusBarHidden: Bool {
        return !SKPhotoBrowserOptions.displayStatusbar
    }

    override open var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .fade
    }
    
    // MARK: - Notification
    @objc open func handleSKPhotoLoadingDidEndNotification(_ notification: Notification) {
        guard let photo = notification.object as? SKPhotoProtocol else {
            return
        }
        
        DispatchQueue.main.async(execute: {
            guard let page = self.pagingScrollView.pageDisplayingAtPhoto(photo), let photo = page.photo else {
                return
            }
            
            if photo.underlyingImage != nil {
                page.displayImage(complete: true)
                self.loadAdjacentPhotosIfNecessary(photo)
            } else {
                page.displayImageFailure()
            }
        })
    }
    
    open func loadAdjacentPhotosIfNecessary(_ photo: SKPhotoProtocol) {
        pagingScrollView.loadAdjacentPhotosIfNecessary(photo, currentPageIndex: currentPageIndex)
    }
    
    // MARK: - initialize / setup
    open func reloadData() {
        performLayout()
        view.setNeedsLayout()
    }
    
    open func performLayout() {
        isPerformingLayout = true
        
        // reset local cache
        pagingScrollView.reload()
        pagingScrollView.updateContentOffset(currentPageIndex)
        pagingScrollView.tilePages()
        
        delegate?.didShowPhotoAtIndex?(self, index: currentPageIndex)
        
        isPerformingLayout = false
    }
    
    open func prepareForClosePhotoBrowser() {
        cancelControlHiding()
        if let panGesture = panGesture {
            view.removeGestureRecognizer(panGesture)
        }
        if let longPressGesture = longPressGesture {
            view.removeGestureRecognizer(longPressGesture)
        }
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }
    
    open func dismissPhotoBrowser(animated: Bool, completion: (() -> Void)? = nil) {
        prepareForClosePhotoBrowser()
        if !animated {
            modalTransitionStyle = .crossDissolve
        }
        dismiss(animated: animated) {
            completion?()
            self.delegate?.didDismissAtPageIndex?(self.currentPageIndex)
        }
    }
    
    open func determineAndClose() {
        delegate?.willDismissAtPageIndex?(self.currentPageIndex)
        dismissPhotoBrowser(animated: true)
    }

    /// Start dismiss without removing gestures; used for interactive pan-to-dismiss. Completion runs when transition ends.
    fileprivate func startInteractiveDismiss(completion: (() -> Void)? = nil) {
        delegate?.willDismissAtPageIndex?(self.currentPageIndex)
        dismiss(animated: true) {
            completion?()
            self.delegate?.didDismissAtPageIndex?(self.currentPageIndex)
        }
    }
    
    open func popupShare(includeCaption: Bool = true) {
        let photo = photos[currentPageIndex]
        
        let image = photo.underlyingImage
        if image == nil {
            return
        }
        
        var activityItems: [AnyObject] = [image!]
        if photo.caption != nil && includeCaption {
            if let shareExtraCaption = SKPhotoBrowserOptions.shareExtraCaption {
                let caption = photo.caption ?? "" + shareExtraCaption
                activityItems.append(caption as AnyObject)
            } else {
                activityItems.append(photo.caption as AnyObject)
            }
        }
        
        if let activityItemProvider = activityItemProvider {
            activityItems.append(activityItemProvider)
        }
        
        activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        activityViewController.completionWithItemsHandler = { (activity, success, items, error) in
            self.hideControlsAfterDelay()
            self.activityViewController = nil
        }
        if UIDevice.current.userInterfaceIdiom == .phone {
            present(activityViewController, animated: true, completion: nil)
        } else {
            activityViewController.modalPresentationStyle = .popover
            let popover: UIPopoverPresentationController! = activityViewController.popoverPresentationController
            popover.barButtonItem = toolbar.toolActionButton
            present(activityViewController, animated: true, completion: nil)
        }
    }
}

// MARK: - Public Function For Customizing Buttons

public extension SKPhotoBrowser {
    func updateCloseButton(_ image: UIImage, size: CGSize? = nil) {
        actionView.updateCloseButton(image: image, size: size)
    }
    
    func updateDeleteButton(_ image: UIImage, size: CGSize? = nil) {
        actionView.updateDeleteButton(image: image, size: size)
    }
}

// MARK: - Public Function For Browser Control

public extension SKPhotoBrowser {
    func initializePageIndex(_ index: Int) {
        let i = min(index, photos.count - 1)
        currentPageIndex = i
        
        if isViewLoaded {
            jumpToPageAtIndex(index)
            if !isViewActive {
                pagingScrollView.tilePages()
            }
            paginationView.update(currentPageIndex)
        }
        self.initPageIndex = currentPageIndex
    }
    
    func jumpToPageAtIndex(_ index: Int) {
        if index < photos.count {
            if !isEndAnimationByToolBar {
                return
            }
            isEndAnimationByToolBar = false
            
            let pageFrame = frameForPageAtIndex(index)
            pagingScrollView.jumpToPageAtIndex(pageFrame)
        }
        hideControlsAfterDelay()
    }
    
    func photoAtIndex(_ index: Int) -> SKPhotoProtocol {
        return photos[index]
    }
    
    @objc func gotoPreviousPage() {
        jumpToPageAtIndex(currentPageIndex - 1)
    }
    
    @objc func gotoNextPage() {
        jumpToPageAtIndex(currentPageIndex + 1)
    }
    
    func cancelControlHiding() {
        if controlVisibilityTimer != nil {
            controlVisibilityTimer.invalidate()
            controlVisibilityTimer = nil
        }
    }
    
    func hideControlsAfterDelay() {
        // reset
        cancelControlHiding()
        // start
        controlVisibilityTimer = Timer.scheduledTimer(timeInterval: 4.0, target: self, selector: #selector(SKPhotoBrowser.hideControls(_:)), userInfo: nil, repeats: false)
    }
    
    func hideControls() {
        setControlsHidden(true, animated: true, permanent: false)
    }
    
    @objc func hideControls(_ timer: Timer) {
        hideControls()
        delegate?.controlsVisibilityToggled?(self, hidden: true)
    }
    
    func toggleControls() {
        let hidden = !areControlsHidden()
        setControlsHidden(hidden, animated: true, permanent: false)
        delegate?.controlsVisibilityToggled?(self, hidden: areControlsHidden())
    }
    
    func areControlsHidden() -> Bool {
        return paginationView.alpha == 0.0
    }
    
    func getCurrentPageIndex() -> Int {
        return currentPageIndex
    }
    
    func addPhotos(photos: [SKPhotoProtocol]) {
        self.photos.append(contentsOf: photos)
        self.reloadData()
    }
    
    func insertPhotos(photos: [SKPhotoProtocol], at index: Int) {
        self.photos.insert(contentsOf: photos, at: index)
        self.reloadData()
    }
}

// MARK: - Internal Function

internal extension SKPhotoBrowser {
    func showButtons() {
        actionView.animate(hidden: false)
    }
    
    func pageDisplayedAtIndex(_ index: Int) -> SKZoomingScrollView? {
        return pagingScrollView.pageDisplayedAtIndex(index)
    }
    
    func getImageFromView(_ sender: UIView) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(sender.frame.size, true, 0.0)
        sender.layer.render(in: UIGraphicsGetCurrentContext()!)
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result!
    }
}

// MARK: - Internal Function For Frame Calc

internal extension SKPhotoBrowser {
    func frameForToolbarAtOrientation() -> CGRect {
        let offset: CGFloat = {
            if #available(iOS 11.0, *) {
                return view.safeAreaInsets.bottom
            } else {
                return 15
            }
        }()
        return view.bounds.divided(atDistance: 44, from: .maxYEdge).slice.offsetBy(dx: 0, dy: -offset)
    }
    
    func frameForToolbarHideAtOrientation() -> CGRect {
        return view.bounds.divided(atDistance: 44, from: .maxYEdge).slice.offsetBy(dx: 0, dy: 44)
    }
    
    func frameForPaginationAtOrientation() -> CGRect {
        let offset = UIDevice.current.orientation.isLandscape ? 35 : 44
        
        return CGRect(x: 0, y: self.view.bounds.size.height - CGFloat(offset), width: self.view.bounds.size.width, height: CGFloat(offset))
    }
    
    func frameForPageAtIndex(_ index: Int) -> CGRect {
        let bounds = pagingScrollView.bounds
        var pageFrame = bounds
        pageFrame.size.width -= (2 * 10)
        pageFrame.origin.x = (bounds.size.width * CGFloat(index)) + 10
        return pageFrame
    }
}

// MARK: - Internal Function For Button Pressed, UIGesture Control

internal extension SKPhotoBrowser {
    @objc func longpress(_ sender: UIGestureRecognizer){
        
        if photos.count > currentPageIndex {
            let photo = photos[currentPageIndex]
            
            let alert = UIAlertController()
            
            let save = UIAlertAction(title: "保存", style: .default, handler: {
                [weak self] ACTION in
                guard let self = self else { return }
                let p = photo as? SKPhoto
                if p != nil {
                    let url = p!.photoURL
                    if url != nil {
                        if url!.lowercased().hasSuffix(".gif"){
                            let data = SKCache.sharedCache.dataForKey(url!)
                            
                            PHPhotoLibrary.shared().performChanges({
                                if #available(iOS 9, *) {
                                    PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data!, options: nil)
                                } else {
                                    // Fallback on earlier versions
                                }
                            }) { [weak self] success, error in
                                guard let self = self else { return }
                                if error != nil {
                                    print(error)
                                }
                            }
                            
                        } else {
                            let image = SKCache.sharedCache.imageForKey(url!)
                            UIImageWriteToSavedPhotosAlbum(image!, nil, nil, nil)
                        }
                    }
                }
                
            })
            
            
            let share = UIAlertAction(title: "分享", style: .default, handler: self.shareHandler)
            let copy = UIAlertAction(title: "复制图片", style: .default, handler: self.copyHandler)

            
            let cancle = UIAlertAction(title: "取消", style: .destructive, handler: {
                [weak self] ACTION in
                guard let _ = self else { return }
            })
            
            //alert.addAction(copy)
            
            alert.addAction(save)
            alert.addAction(share)
            alert.addAction(copy)
            alert.addAction(cancle)
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                
                
                alert.modalPresentationStyle = .popover
                //let popover: UIPopoverPresentationController! = activityViewController.popoverPresentationController
                //popover.barButtonItem = self.toolbar.toolActionButton
                
                alert.popoverPresentationController?.sourceView = self.view
                alert.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)

            }
            self.present(alert, animated: true, completion: nil)
            
        }
    }

    func shareHandler(sender:UIAlertAction) {
        
        let alert = UIAlertController()

        let photo = photos[currentPageIndex]

        let p = photo as? SKPhoto
        if p != nil {
            let url = p!.photoURL
            if url != nil {
                if url!.lowercased().hasSuffix(".gif"){
                    let data = SKCache.sharedCache.dataForKey(url!)
                    
                    let items: [Any] = [data as Any]
                    let activityViewController:UIActivityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)

                    if UIDevice.current.userInterfaceIdiom == .phone {
                        self.present(activityViewController, animated: true, completion: nil)
                    } else {
                        activityViewController.popoverPresentationController?.sourceView = self.view

                        self.present(activityViewController, animated: true, completion: nil)
                    }
                    
                } else {
                    let image = SKCache.sharedCache.imageForKey(url!)
                    
                    let items: Array = [image]
                    let activityViewController:UIActivityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        self.present(activityViewController, animated: true, completion: nil)
                    } else {
                        activityViewController.popoverPresentationController?.sourceView = self.view
                        self.present(activityViewController, animated: true, completion: nil)
                    }
                    
                    
                    
                }
            }
        }
    }

    func copyHandler(sender:UIAlertAction) {
        let photo = photos[currentPageIndex]
        let p = photo as? SKPhoto
        if p != nil {
            let url = p!.photoURL
            if url != nil {
                if url!.lowercased().hasSuffix(".gif"){
                    let data = SKCache.sharedCache.dataForKey(url!)
                    UIPasteboard.general.setData(data!, forPasteboardType: "public.gif")
                } else {
                    let image = SKCache.sharedCache.imageForKey(url!)
                    UIPasteboard.general.image = image
                }
            }
        }
    }

    @objc private func panGestureRecognized(_ sender: UIPanGestureRecognizer) {
        guard let zoomingScrollView = pageDisplayedAtIndex(currentPageIndex) else { return }
        
        let translation = sender.translation(in: view)
        let velocity = sender.velocity(in: view)
        
        switch sender.state {
        case .began:
            guard shouldAllowPanToDismiss(for: zoomingScrollView) else { return }
            
            hideControls()
            isInteractivelyDismissing = true
            
            // Calculate origin frame
            let originView = delegate?.viewForPhoto?(self, index: currentPageIndex) ?? animator.senderViewForAnimation
            if let originView = originView, let window = originView.window {
                let rectInWindow = originView.convert(originView.bounds, to: window)
                interactiveDismissOriginFrame = view.convert(rectInWindow, from: nil)
            } else {
                interactiveDismissOriginFrame = .zero
            }
            
            // Create snapshot
            guard let snapshot = zoomingScrollView.imageView.snapshotView(afterScreenUpdates: true) else {
                return
            }
            interactiveDismissSnapshot = snapshot
            
            // Setup snapshot frame
            let frameInView = zoomingScrollView.imageView.convert(zoomingScrollView.imageView.bounds, to: view)
            snapshot.frame = frameInView
            snapshot.contentMode = .scaleAspectFill
            
            view.addSubview(snapshot)
            zoomingScrollView.imageView.isHidden = true
            
        case .changed:
            guard isInteractivelyDismissing, let snapshot = interactiveDismissSnapshot else { return }
            
            // 1. Follow finger
            let initialCenter = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            snapshot.center = CGPoint(x: initialCenter.x + translation.x, y: initialCenter.y + translation.y)
            
            // 2. Scale down as you drag (minimum 0.5)
            // Use translation.y to determine scale factor
            let progress = max(translation.y / view.bounds.height, 0)
            let scale = max(0.5, 1 - progress * 1.2)
            snapshot.transform = CGAffineTransform(scaleX: scale, y: scale)
            
            // 3. Fade background
            // Fade out faster than scaling
            let alpha = max(0, 1 - progress * 2.0)
            view.backgroundColor = bgColor.withAlphaComponent(alpha)
            
        case .ended, .cancelled:
            guard isInteractivelyDismissing, let snapshot = interactiveDismissSnapshot else { return }
            
            let dismissThreshold: CGFloat = 100
            let velocityThreshold: CGFloat = 800
            
            // Dismiss if dragged down enough OR flicked down fast enough
            let shouldDismiss = (translation.y > dismissThreshold) || (velocity.y > velocityThreshold && translation.y > 0)
            
            if shouldDismiss {
                // Animate to origin (close)
                UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
                    if self.interactiveDismissOriginFrame != .zero {
                        snapshot.frame = self.interactiveDismissOriginFrame
                    } else {
                        snapshot.alpha = 0
                        snapshot.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
                    }
                    self.view.backgroundColor = UIColor.clear
                    self.actionView.alpha = 0 // Ensure other UI elements fade out
                    self.paginationView.alpha = 0
                    self.toolbar.alpha = 0
                }, completion: { _ in
                    self.dismissPhotoBrowser(animated: false)
                    snapshot.removeFromSuperview()
                })
            } else {
                // Cancel (snap back)
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
                    snapshot.transform = .identity
                    snapshot.center = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
                    self.view.backgroundColor = self.bgColor
                }, completion: { _ in
                    zoomingScrollView.imageView.isHidden = false
                    snapshot.removeFromSuperview()
                    self.interactiveDismissSnapshot = nil
                    self.isInteractivelyDismissing = false
                    if !self.areControlsHidden() {
                        self.showButtons()
                    }
                })
            }
            
        default:
            break
        }
    }
    
    
    @objc func actionButtonPressed(ignoreAndShare: Bool) {
        delegate?.willShowActionSheet?(currentPageIndex)
        
        guard photos.count > 0 else {
            return
        }
        
        if let titles = SKPhotoBrowserOptions.actionButtonTitles {
            let actionSheetController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            actionSheetController.addAction(UIAlertAction(title: cancelTitle, style: .cancel))
            
            for idx in titles.indices {
                actionSheetController.addAction(UIAlertAction(title: titles[idx], style: .default, handler: { (_) -> Void in
                    self.delegate?.didDismissActionSheetWithButtonIndex?(idx, photoIndex: self.currentPageIndex)
                }))
            }
            
            if UIDevice.current.userInterfaceIdiom == .phone {
                present(actionSheetController, animated: true, completion: nil)
            } else {
                actionSheetController.modalPresentationStyle = .popover
                
                if let popoverController = actionSheetController.popoverPresentationController {
                    popoverController.sourceView = self.view
                    popoverController.barButtonItem = toolbar.toolActionButton
                }
                
                present(actionSheetController, animated: true, completion: { () -> Void in
                })
            }
            
        } else {
            popupShare()
        }
    }
    
    func deleteImage() {
        defer {
            reloadData()
        }
        
        if photos.count > 1 {
            pagingScrollView.deleteImage()
            
            photos.remove(at: currentPageIndex)
            if currentPageIndex != 0 {
                gotoPreviousPage()
            }
            paginationView.update(currentPageIndex)
            
        } else if photos.count == 1 {
            dismissPhotoBrowser(animated: true)
        }
    }
}

// MARK: - Private Function
private extension SKPhotoBrowser {
    func shouldAllowPanToDismiss(for zoomingScrollView: SKZoomingScrollView) -> Bool {
        if zoomingScrollView.zoomScale > 1.0 {
            return false
        }
        if zoomingScrollView.contentOffset.y > 0 {
            return false
        }
        return true
    }

    func configureAppearance() {
        view.backgroundColor = bgColor
        view.clipsToBounds = true
        view.isOpaque = false
        
        if #available(iOS 11.0, *) {
            view.accessibilityIgnoresInvertColors = true
        }
    }
    
    func configurePagingScrollView() {
        pagingScrollView.delegate = self
        view.addSubview(pagingScrollView)
    }
    
    func configureGestureControl() {
        guard !SKPhotoBrowserOptions.disableVerticalSwipe else { return }
        
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(SKPhotoBrowser.panGestureRecognized(_:)))
        panGesture?.minimumNumberOfTouches = 1
        panGesture?.maximumNumberOfTouches = 1
        panGesture?.delegate = self
        
        if let panGesture = panGesture {
            view.addGestureRecognizer(panGesture)
            // Let our vertical-dismiss pan get first chance; horizontal paging only when our pan fails
            pagingScrollView.panGestureRecognizer.require(toFail: panGesture)
        }
        
        longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(SKPhotoBrowser.longpress(_:)))
        longPressGesture?.minimumPressDuration = 0.5
        longPressGesture?.delaysTouchesBegan = false
        if let longPressRecognizer = longPressGesture {
            view.addGestureRecognizer(longPressRecognizer)
        }
    }
    
    func configureActionView() {
        actionView = SKActionView(frame: view.frame, browser: self)
        view.addSubview(actionView)
    }
    
    func configurePaginationView() {
        paginationView = SKPaginationView(frame: view.frame, browser: self)
        view.addSubview(paginationView)
    }
    
    func configureToolbar() {
        toolbar = SKToolbar(frame: frameForToolbarAtOrientation(), browser: self)
        view.addSubview(toolbar)
    }
    
    func setControlsHidden(_ hidden: Bool, animated: Bool, permanent: Bool) {
        // timer update
        cancelControlHiding()
        
        // scroll animation
        pagingScrollView.setControlsHidden(hidden: hidden)
        
        // paging animation
        paginationView.setControlsHidden(hidden: hidden)
        
        // action view animation
        actionView.animate(hidden: hidden)
        
        if !hidden && !permanent {
            hideControlsAfterDelay()
        }
        setNeedsStatusBarAppearanceUpdate()
    }
}

// MARK: - UIScrollView Delegate

extension SKPhotoBrowser: UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard isViewActive else { return }
        guard !isPerformingLayout else { return }
        
        // tile page
        pagingScrollView.tilePages()
        
        // Calculate current page
        let previousCurrentPage = currentPageIndex
        let visibleBounds = pagingScrollView.bounds
        currentPageIndex = min(max(Int(floor(visibleBounds.midX / visibleBounds.width)), 0), photos.count - 1)
        
        if currentPageIndex != previousCurrentPage {
            delegate?.didShowPhotoAtIndex?(self, index: currentPageIndex)
            paginationView.update(currentPageIndex)
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        hideControlsAfterDelay()
        
        let currentIndex = pagingScrollView.contentOffset.x / pagingScrollView.frame.size.width
        delegate?.didScrollToIndex?(self, index: Int(currentIndex))
    }
    
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        isEndAnimationByToolBar = true
    }
}

// MARK: - UIViewControllerTransitioningDelegate

extension SKPhotoBrowser: UIViewControllerTransitioningDelegate {
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return SKPhotoBrowserPresentAnimator()
    }

    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return SKPhotoBrowserDismissAnimator()
    }

    public func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return isInteractivelyDismissing ? dismissInteractionController : nil
    }
}

// MARK: - UIGestureRecognizerDelegate

extension SKPhotoBrowser: UIGestureRecognizerDelegate {
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
              let zoomingScrollView = pagingScrollView.pageDisplayedAtIndex(currentPageIndex) else {
            return true
        }
        
        guard shouldAllowPanToDismiss(for: zoomingScrollView) else { return false }

        let velocity = pan.velocity(in: view)
        let translation = pan.translation(in: view)
        
        // Only allow swipe down
        if translation.y <= 0 { return false }

        // If it's clearly more horizontal than vertical, don't start
        let absVx = abs(velocity.x)
        let absVy = abs(velocity.y)
        if absVx > absVy * 1.2 { return false }

        return true
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
