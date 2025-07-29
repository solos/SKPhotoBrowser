//
//  SKPhotoBrowser.h
//  SKPhotoBrowser
//
//  Created by 鈴木 啓司 on 2015/10/09.
//  Copyright © 2015年 suzuki_keishi. All rights reserved.
//

#import <UIKit/UIKit.h>

#if __has_include("UIImage+animatedGIF.h")
#import "UIImage+animatedGIF.h"
#endif

// Live Photo support (iOS 9.1+)
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_9_1
#import <PhotosUI/PhotosUI.h>
#endif

//! Project version number for SKPhotoBrowser.
FOUNDATION_EXPORT double SKPhotoBrowserVersionNumber;

//! Project version string for SKPhotoBrowser.
FOUNDATION_EXPORT const unsigned char SKPhotoBrowserVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <SKPhotoBrowser/PublicHeader.h>


