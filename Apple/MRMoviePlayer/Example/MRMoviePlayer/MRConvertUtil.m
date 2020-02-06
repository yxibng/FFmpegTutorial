//
//  MRConvertUtil.m
//  MRMoviePlayer
//
//  Created by Matt Reach on 2019/1/25.
//  Copyright © 2019 Awesome FFmpeg Study Demo. All rights reserved.
//

#import "MRConvertUtil.h"
#import <CoreGraphics/CoreGraphics.h>

#define BYTE_ALIGN_2(_s_) (( _s_ + 1)/2 * 2)

@implementation MRConvertUtil

#pragma mark - YUV(NV12)-->CVPixelBufferRef Conversion

//https://stackoverflow.com/questions/25659671/how-to-convert-from-yuv-to-ciimage-for-ios
+ (CVPixelBufferRef)pixelBufferFromAVFrame:(AVFrame*)aFrame
{
    return [self pixelBufferFromAVFrame:aFrame opt:NULL];
}

+ (CVPixelBufferRef)pixelBufferFromAVFrame:(AVFrame*)aFrame opt:(CVPixelBufferPoolRef _Nullable)poolRef
{
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn result = kCVReturnError;
    int w = aFrame->width;
    int h = aFrame->height;
    if (poolRef) {
        result = CVPixelBufferPoolCreatePixelBuffer(NULL, poolRef, &pixelBuffer);
    } else {
        NSDictionary *pixelAttributes = @{(NSString*)kCVPixelBufferIOSurfacePropertiesKey:@{}};
        
        result = CVPixelBufferCreate(kCFAllocatorDefault,
                                     w,
                                     h,
                                     kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                                     (__bridge CFDictionaryRef)(pixelAttributes),
                                     &pixelBuffer);
    }
    
    if (kCVReturnSuccess == result) {
        CVPixelBufferLockBaseAddress(pixelBuffer,0);
        unsigned char *yDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
        
        // Here y_ch0 is Y-Plane of YUV(NV12) data.
        
        unsigned char *y_ch0 = aFrame->data[0];
        unsigned char *y_ch1 = aFrame->data[1];
        // important !! 这里不能使用 w ，因为ffmpeg对数据做了字节对齐！！会导致绿屏！如果视频宽度刚好就是一个对齐的大小时，w就和linesize[0]相等，所以没问题；
        memcpy(yDestPlane, y_ch0, aFrame->linesize[0] * h);
        unsigned char *uvDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
        
        // Here y_ch1 is UV-Plane of YUV(NV12) data.
        memcpy(uvDestPlane, y_ch1, aFrame->linesize[1] * BYTE_ALIGN_2(h)/2);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    }
    
    return (CVPixelBufferRef)CFAutorelease(pixelBuffer);
}

+ (UIImage *)imageFromCVPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    // CIImage Conversion
    CIImage *coreImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    CIContext *context = [CIContext contextWithOptions:nil];
    ///引发内存泄露? https://stackoverflow.com/questions/32520082/why-is-cicontext-createcgimage-causing-a-memory-leak
    NSTimeInterval begin = CFAbsoluteTimeGetCurrent();
    
    CGSize size = CVImageBufferGetDisplaySize(pixelBuffer);
    
    CGImageRef cgImage = [context createCGImage:coreImage
                                       fromRect:CGRectMake(0, 0, size.width, size.height)];
    NSTimeInterval end = CFAbsoluteTimeGetCurrent();
    // UIImage Conversion
    UIImage *uiImage = [[UIImage alloc] initWithCGImage:cgImage
                                                  scale:1.0
                                            orientation:UIImageOrientationUp];
    
    NSLog(@"decode an image cost :%g",end-begin);
    CGImageRelease(cgImage);
    return uiImage;
}

+ (UIImage *)imageFromAVFrameOverBitmap:(AVFrame*)aFrame
{
    int w = aFrame->width;
    int h = aFrame->height;
    
    const UInt8 *rgb   = aFrame->data[0];
    size_t bytesPerRow = aFrame->linesize[0];
    CFIndex length     = bytesPerRow * h;
    
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    ///需要copy！因为video_frame是重复利用的；里面的数据会变化！
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, rgb, length);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGImageRef cgImage = CGImageCreate(w,
                                       h,
                                       8,
                                       24,
                                       bytesPerRow,
                                       colorSpace,
                                       bitmapInfo,
                                       provider,
                                       NULL,
                                       NO,
                                       kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGDataProviderRelease(provider);
    CFRelease(data);
    
    return image;
}

+ (UIImage *)imageFromAVFrameOverPixelBuffer:(AVFrame*)aFrame
{
    CVPixelBufferRef pixelBuffer = [self pixelBufferFromAVFrame:aFrame];
    if (pixelBuffer) {
        return [self imageFromCVPixelBuffer:pixelBuffer];
    }
    return nil;
}

#pragma mark - CVPixelBufferRef-->CMSampleBufferRef

+ (CMSampleBufferRef)cmSampleBufferRefFromCVPixelBufferRef:(CVPixelBufferRef)pixelBuffer
{
    if (pixelBuffer) {
        //不设置具体时间信息
        CMSampleTimingInfo timing = {kCMTimeInvalid, kCMTimeInvalid, kCMTimeInvalid};
        //获取视频信息
        CMVideoFormatDescriptionRef videoInfo = NULL;
        OSStatus result = CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);
        NSParameterAssert(result == 0 && videoInfo != NULL);
        
        CMSampleBufferRef sampleBuffer = NULL;
        result = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,pixelBuffer, true, NULL, NULL, videoInfo, &timing, &sampleBuffer);
        NSParameterAssert(result == 0 && sampleBuffer != NULL);
        CFRelease(videoInfo);
        
        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
        CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
        
        return (CMSampleBufferRef)CFAutorelease(sampleBuffer);
    }
    return NULL;
}

@end
