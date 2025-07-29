# Live Photo Implementation in SKPhotoBrowser

This document describes the implementation of Live Photo support in SKPhotoBrowser.

## Overview

Live Photo support has been added to SKPhotoBrowser with the following features:
- Display Live Photos with their cover image
- Tap-to-play functionality for Live Photo animation
- Support for zooming and panning Live Photos
- Automatic fallback to static image if Live Photo is not available
- Integration with existing SKPhotoBrowser features

## New Files Added

### 1. SKLivePhoto.swift
- New class `SKLivePhoto` that implements `SKPhotoProtocol`
- Supports both `PHLivePhoto` objects and Live Photo URLs
- Handles Live Photo loading and caching
- Provides static factory methods for easy creation

### 2. SKLivePhotoView.swift
- New view component `SKLivePhotoView` for displaying Live Photos
- Contains both `PHLivePhotoView` and `UIImageView` for fallback
- Implements tap-to-play functionality
- Handles content mode and layout

### 3. FromLivePhotoViewController.swift
- Example implementation showing how to use Live Photos
- Demonstrates loading Live Photos from photo library
- Shows mixed content (regular photos + Live Photos)

### 4. SKLivePhotoTests.swift
- Unit tests for Live Photo functionality
- Tests creation, properties, and protocol conformance

## Modified Files

### 1. SKZoomingScrollView.swift
- Added `SKLivePhotoView` support
- Modified `displayImage` method to handle Live Photos
- Updated zoom handling for Live Photo views
- Added availability checks for iOS 9.1+

### 2. SKPhotoBrowser.h
- Added PhotosUI framework import
- Added availability checks for Live Photo support

### 3. SKPhotoBrowser.swift
- Added PhotosUI import
- Updated photo handling to support Live Photos

## Key Implementation Details

### Live Photo Detection
```swift
if #available(iOS 9.1, *) {
    if let livePhoto = photo as? SKLivePhoto, livePhoto.isLivePhoto, livePhoto.livePhoto != nil {
        displayLivePhoto(livePhoto.livePhoto!, image: image)
        return
    }
}
```

### Tap-to-Play Implementation
```swift
public func handleSingleTap(_ view: UIView, touch: UITouch) {
    if isLivePhotoAvailable {
        if isPlaying() {
            stopPlayback()
        } else {
            startPlayback()
        }
    }
}
```

### Zoom Support
```swift
public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    if #available(iOS 9.1, *) {
        if let livePhotoView = livePhotoView, !livePhotoView.isHidden {
            return livePhotoView
        }
    }
    return imageView
}
```

## Usage Examples

### Basic Live Photo Usage
```swift
let livePhoto = PHLivePhoto() // Your Live Photo
let thumbnailImage = UIImage() // Thumbnail
let photo = SKLivePhoto.photoWithLivePhoto(livePhoto, image: thumbnailImage)
```

### Loading from Photo Library
```swift
PHImageManager.default().requestLivePhoto(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { [weak self] (livePhoto, info) in
    let photo = SKLivePhoto.photoWithLivePhoto(livePhoto)
    self.images.append(photo)
}
```

### Mixed Content
```swift
var images = [SKPhotoProtocol]()
images.append(SKPhoto.photoWithImage(regularImage))
images.append(SKLivePhoto.photoWithLivePhoto(livePhoto, image: thumbnailImage))
```

## Requirements

- iOS 9.1 or later for Live Photo support
- PhotosUI framework
- Photo Library permission (if loading from library)

## Performance Considerations

1. **Memory Usage**: Live Photos require more memory than regular photos
2. **Loading Strategy**: Consider loading Live Photos on demand
3. **Caching**: Implement appropriate caching for Live Photo data
4. **Fallback**: Always provide a static image as fallback

## Testing

The implementation includes:
- Unit tests for `SKLivePhoto` class
- Example implementation in demo app
- Integration tests for zoom and tap functionality

## Future Enhancements

Potential improvements for future versions:
1. Better Live Photo file format support
2. Advanced caching strategies
3. Custom Live Photo playback controls
4. Support for Live Photo editing
5. Better performance optimizations

## Compatibility

- Backward compatible with existing SKPhotoBrowser usage
- Regular photos continue to work as before
- Live Photos are only available on iOS 9.1+
- Graceful fallback to static images when Live Photo is not available 