# Live Photo Support in SKPhotoBrowser

SKPhotoBrowser now supports Live Photos with tap-to-play functionality. This feature is available for iOS 9.1 and later.

## Features

- Display Live Photos with their cover image
- Tap to play/stop Live Photo animation
- Support for zooming and panning Live Photos
- Automatic fallback to static image if Live Photo is not available
- Integration with existing SKPhotoBrowser features

## Basic Usage

### 1. Import Required Frameworks

```swift
import SKPhotoBrowser
import PhotosUI
```

### 2. Create Live Photo Objects

```swift
// From PHLivePhoto object
let livePhoto = PHLivePhoto() // Your Live Photo object
let thumbnailImage = UIImage() // Thumbnail image for the Live Photo

let photo = SKLivePhoto.photoWithLivePhoto(livePhoto, image: thumbnailImage)
photo.caption = "My Live Photo"
```

### 3. Display in Photo Browser

```swift
var images = [SKPhotoProtocol]()
images.append(photo)

let browser = SKPhotoBrowser(photos: images, initialPageIndex: 0)
present(browser, animated: true, completion: {})
```

## Loading Live Photos from Photo Library

### 1. Request Photo Library Permission

```swift
import Photos

PHPhotoLibrary.requestAuthorization { status in
    if status == .authorized {
        // Load Live Photos
        self.loadLivePhotosFromLibrary()
    }
}
```

### 2. Fetch Live Photos

```swift
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
                    // Create SKLivePhoto
                    let photo = SKLivePhoto.photoWithLivePhoto(livePhoto)
                    photo.caption = "Live Photo from Library"
                    self.images.append(photo)
                    
                    // Update UI
                    self.collectionView.reloadData()
                }
            }
        }
    }
}
```

## Advanced Usage

### Custom Live Photo Loading

```swift
// Load Live Photo from URL (if you have Live Photo files)
let livePhotoURL = URL(string: "https://example.com/livephoto.mov")!
let photo = SKLivePhoto.photoWithLivePhotoURL(livePhotoURL, image: thumbnailImage)
```

### Handling Live Photo Playback

```swift
// The Live Photo will automatically handle tap-to-play
// Users can tap on the Live Photo to start/stop playback
// No additional code is required for basic functionality
```

### Mixed Content

```swift
// You can mix regular photos and Live Photos in the same browser
var images = [SKPhotoProtocol]()

// Regular photo
let regularPhoto = SKPhoto.photoWithImage(UIImage())
images.append(regularPhoto)

// Live Photo
let livePhoto = SKLivePhoto.photoWithLivePhoto(phLivePhoto, image: thumbnailImage)
images.append(livePhoto)

let browser = SKPhotoBrowser(photos: images, initialPageIndex: 0)
present(browser, animated: true, completion: {})
```

## Requirements

- iOS 9.1 or later
- PhotosUI framework
- Photo Library permission (if loading from library)

## Notes

- Live Photos require more memory than regular photos
- Consider loading Live Photos on demand for better performance
- The tap-to-play functionality is built-in and requires no additional setup
- Live Photos will automatically fall back to their cover image if the Live Photo data is not available

## Example Project

See the `FromLivePhotoViewController.swift` in the example project for a complete implementation. 