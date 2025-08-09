//
//  FromLivePhotoViewController.swift
//  SKPhotoBrowserExample
//
//  Created by SKPhotoBrowser on 2024/01/01.
//  Copyright © 2024 SKPhotoBrowser. All rights reserved.
//

import UIKit
import SKPhotoBrowser
import PhotosUI

@available(iOS 9.1, *)
class FromLivePhotoViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, SKPhotoBrowserDelegate {
    @IBOutlet weak var collectionView: UICollectionView!
    
    var images = [SKPhotoProtocol]()
    var livePhotos = [PHLivePhoto]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Static setup
        SKPhotoBrowserOptions.displayAction = true
        SKPhotoBrowserOptions.displayStatusbar = true
        SKPhotoBrowserOptions.displayCounterLabel = true
        SKPhotoBrowserOptions.displayBackAndForwardButton = true

        setupTestData()
        setupCollectionView()
    }

    override var prefersStatusBarHidden: Bool {
        return false
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

// MARK: - UICollectionViewDataSource
@available(iOS 9.1, *)
extension FromLivePhotoViewController {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
    
    @objc(collectionView:cellForItemAtIndexPath:) func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "exampleCollectionViewCell", for: indexPath) as? ExampleCollectionViewCell else {
            return UICollectionViewCell()
        }
        
        // Use regular image for thumbnail
        cell.exampleImageView.image = UIImage(named: "image\((indexPath as NSIndexPath).row % 10).jpg")
        return cell
    }
}

// MARK: - UICollectionViewDelegate
@available(iOS 9.1, *)
extension FromLivePhotoViewController {
    @objc(collectionView:didSelectItemAtIndexPath:) func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let browser = SKPhotoBrowser(photos: images, initialPageIndex: indexPath.row)
        browser.delegate = self

        present(browser, animated: true, completion: {})
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: IndexPath) -> CGSize {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return CGSize(width: UIScreen.main.bounds.size.width / 2 - 5, height: 300)
        } else {
            return CGSize(width: UIScreen.main.bounds.size.width / 2 - 5, height: 200)
        }
    }
}

// MARK: - SKPhotoBrowserDelegate
@available(iOS 9.1, *)
extension FromLivePhotoViewController {
    func didShowPhotoAtIndex(_ index: Int) {
        //collectionView.visibleCells.forEach({$0.isHidden = false})
        //collectionView.cellForItem(at: IndexPath(item: index, section: 0))?.isHidden = true
    }
    
    func willDismissAtPageIndex(_ index: Int) {
        //collectionView.visibleCells.forEach({$0.isHidden = false})
        //collectionView.cellForItem(at: IndexPath(item: index, section: 0))?.isHidden = true
    }
    
    func willShowActionSheet(_ photoIndex: Int) {
        // do some handle if you need
    }
    
    func didDismissAtPageIndex(_ index: Int) {
        //collectionView.cellForItem(at: IndexPath(item: index, section: 0))?.isHidden = false
    }
    
    func didDismissActionSheetWithButtonIndex(_ buttonIndex: Int, photoIndex: Int) {
        // handle dismissing custom actions
    }
    
    func removePhoto(_ browser: SKPhotoBrowser, index: Int, reload: @escaping (() -> Void)) {
        reload()
    }

    func viewForPhoto(_ browser: SKPhotoBrowser, index: Int) -> UIView? {
        return collectionView.cellForItem(at: IndexPath(item: index, section: 0))
    }
    
    func captionViewForPhotoAtIndex(index: Int) -> SKCaptionView? {
        return nil
    }
}

// MARK: - private
@available(iOS 9.1, *)
private extension FromLivePhotoViewController {
    func setupTestData() {
        images = createLivePhotoPhotos()
    }
    
    func setupCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self
    }
    
    func createLivePhotoPhotos() -> [SKPhotoProtocol] {
        return (0..<10).map { (i: Int) -> SKPhotoProtocol in
            let image = UIImage(named: "image\(i%10).jpg")!
            
            // Create a mock Live Photo for demonstration
            // In a real app, you would load actual Live Photos from the photo library
            let photo = SKLivePhoto.photoWithLivePhoto(createMockLivePhoto(), image: image)
            photo.caption = "Live Photo \(i + 1): \(caption[i%10])"
            return photo
        }
    }
    
    func createMockLivePhoto() -> PHLivePhoto {
        // This is a mock implementation
        // In a real app, you would load actual Live Photos from the photo library
        // For demonstration purposes, we'll create a simple Live Photo
        
        // Create a simple image for the Live Photo
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        UIColor.blue.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Create a simple Live Photo (this is a simplified version)
        // In a real implementation, you would need to create proper Live Photo files
        let livePhoto = PHLivePhoto()
        
        return livePhoto
    }
}

// MARK: - Live Photo Helper
@available(iOS 9.1, *)
extension FromLivePhotoViewController {
    func loadLivePhotosFromLibrary() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        fetchResult.enumerateObjects { [weak self] (asset, index, stop) in
            guard let self = self else { return }
            
            // Check if the asset has Live Photo data
            if asset.mediaSubtypes.contains(.photoLive) {
                let options = PHLivePhotoRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.isNetworkAccessAllowed = true
                
                PHImageManager.default().requestLivePhoto(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { [weak self] (livePhoto, info) in
                    guard let self = self, let livePhoto = livePhoto else { return }
                    
                    DispatchQueue.main.async {
                        self.livePhotos.append(livePhoto)
                        
                        // Create SKLivePhoto
                        let photo = SKLivePhoto.photoWithLivePhoto(livePhoto)
                        photo.caption = "Live Photo from Library \(self.livePhotos.count)"
                        self.images.append(photo)
                        
                        // Reload collection view if needed
                        if self.images.count <= 10 {
                            self.collectionView.reloadData()
                        }
                    }
                }
            }
        }
    }
} 