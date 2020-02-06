//
//  MRConvertUtil.h
//  MRMoviePlayer
//
//  Created by Matt Reach on 2019/1/25.
//  Copyright © 2019 Awesome FFmpeg Study Demo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreVideo/CVPixelBuffer.h>
#import <CoreMedia/CMSampleBuffer.h>
#import <libavutil/frame.h>

@interface MRConvertUtil : NSObject

+ (CVPixelBufferRef)pixelBufferFromAVFrame:(AVFrame*)pFrame;
+ (CVPixelBufferRef)pixelBufferFromAVFrame:(AVFrame*)pFrame opt:(CVPixelBufferPoolRef)poolRef;

+ (UIImage *)imageFromCVPixelBuffer:(CVPixelBufferRef)pixelBuffer;
+ (UIImage *)imageFromAVFrameOverBitmap:(AVFrame*)aFrame;
+ (UIImage *)imageFromAVFrameOverPixelBuffer:(AVFrame*)aFrame;

+ (CMSampleBufferRef)cmSampleBufferRefFromCVPixelBufferRef:(CVPixelBufferRef)pixelBuffer;

@end
