//
//  MRConvertUtil.h
//  MRMoviePlayer
//
//  Created by Matt Reach on 2019/1/25.
//  Copyright © 2019 Awesome FFmpeg Study Demo. All rights reserved.
//
// CFAutorelease CVPixelBufferRef or CMSampleBufferRef cause memory leak！

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreVideo/CVPixelBuffer.h>
#import <CoreMedia/CMSampleBuffer.h>
#import <libavutil/frame.h>

@interface MRConvertUtil : NSObject

///need CFRelease the result
+ (CVPixelBufferRef)createCVPixelBufferFromAVFrame:(AVFrame*)pFrame;
///need CFRelease the result
+ (CVPixelBufferRef)createCVPixelBufferFromAVFrame:(AVFrame*)pFrame opt:(CVPixelBufferPoolRef)poolRef;

+ (UIImage *)imageFromCVPixelBuffer:(CVPixelBufferRef)pixelBuffer;
+ (UIImage *)imageFromAVFrameOverBitmap:(AVFrame*)aFrame;
+ (UIImage *)imageFromAVFrameOverPixelBuffer:(AVFrame*)aFrame;
///need CFRelease the result
+ (CMSampleBufferRef)createCMSampleBufferFromCVPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end
