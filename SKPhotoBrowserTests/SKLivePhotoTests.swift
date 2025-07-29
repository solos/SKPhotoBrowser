//
//  SKLivePhotoTests.swift
//  SKPhotoBrowserTests
//
//  Created by SKPhotoBrowser on 2024/01/01.
//  Copyright © 2024 SKPhotoBrowser. All rights reserved.
//

import XCTest
import SKPhotoBrowser
import PhotosUI

@available(iOS 9.1, *)
class SKLivePhotoTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called before the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSKLivePhotoCreation() {
        // Test creating SKLivePhoto with image
        let image = UIImage()
        let photo = SKLivePhoto.photoWithLivePhoto(createMockLivePhoto(), image: image)
        
        XCTAssertNotNil(photo)
        XCTAssertEqual(photo.underlyingImage, image)
        XCTAssertTrue(photo.isLivePhoto)
    }
    
    func testSKLivePhotoWithURL() {
        // Test creating SKLivePhoto with URL
        let url = URL(string: "https://example.com/livephoto.mov")!
        let image = UIImage()
        let photo = SKLivePhoto.photoWithLivePhotoURL(url, image: image)
        
        XCTAssertNotNil(photo)
        XCTAssertEqual(photo.livePhotoURL, url)
        XCTAssertEqual(photo.underlyingImage, image)
        XCTAssertTrue(photo.isLivePhoto)
    }
    
    func testSKLivePhotoProtocol() {
        // Test that SKLivePhoto conforms to SKPhotoProtocol
        let photo = SKLivePhoto.photoWithLivePhoto(createMockLivePhoto())
        
        XCTAssertTrue(photo is SKPhotoProtocol)
        XCTAssertEqual(photo.index, 0)
        XCTAssertNil(photo.caption)
        XCTAssertEqual(photo.contentMode, .scaleAspectFill)
    }
    
    func testSKLivePhotoCaption() {
        // Test setting caption on SKLivePhoto
        let photo = SKLivePhoto.photoWithLivePhoto(createMockLivePhoto())
        photo.caption = "Test Live Photo"
        
        XCTAssertEqual(photo.caption, "Test Live Photo")
    }
    
    func testSKLivePhotoIndex() {
        // Test setting index on SKLivePhoto
        let photo = SKLivePhoto.photoWithLivePhoto(createMockLivePhoto())
        photo.index = 5
        
        XCTAssertEqual(photo.index, 5)
    }
    
    func testSKLivePhotoContentMode() {
        // Test setting content mode on SKLivePhoto
        let photo = SKLivePhoto.photoWithLivePhoto(createMockLivePhoto())
        photo.contentMode = .scaleAspectFit
        
        XCTAssertEqual(photo.contentMode, .scaleAspectFit)
    }
    
    // MARK: - Helper Methods
    
    private func createMockLivePhoto() -> PHLivePhoto {
        // Create a simple mock Live Photo for testing
        // In a real implementation, this would be a proper Live Photo
        let livePhoto = PHLivePhoto()
        return livePhoto
    }
} 