//
//  MRConvertUtil.m
//  MRMoviePlayer
//
//  Created by Matt Reach on 2019/1/25.
//  Copyright © 2019 Awesome FFmpeg Study Demo. All rights reserved.
//

#import "MRConvertUtil.h"
#import <CoreGraphics/CoreGraphics.h>

#define BYTE_ALIGN_X(_s_,_x_) (( _s_ + _x_ - 1)/_x_ * _x_)
#define BYTE_ALIGN_2(_s_) (BYTE_ALIGN_X(_s_,2))

@implementation MRConvertUtil

#pragma mark - YUV(NV12)-->CVPixelBufferRef Conversion

//https://stackoverflow.com/questions/25659671/how-to-convert-from-yuv-to-ciimage-for-ios
+ (CVPixelBufferRef)createCVPixelBufferFromAVFrame:(AVFrame*)aFrame
{
    return [self createCVPixelBufferFromAVFrame:aFrame opt:NULL];
}

+ (CVPixelBufferRef)createCVPixelBufferFromAVFrame:(AVFrame*)aFrame opt:(CVPixelBufferPoolRef _Nullable)poolRef
{
    NSParameterAssert(aFrame->format == AV_PIX_FMT_NV12);
    
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn result = kCVReturnError;
    if (poolRef) {
        result = CVPixelBufferPoolCreatePixelBuffer(NULL, poolRef, &pixelBuffer);
    } else {
        int w = aFrame->width;
        int h = aFrame->height;
        int linesize = 32;//aFrame->linesize[0];//BYTE_ALIGN_X(w,64);//
        
        NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
//        [attributes setObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
//        [attributes setObject:[NSNumber numberWithInt:w] forKey: (NSString*)kCVPixelBufferWidthKey];
//        [attributes setObject:[NSNumber numberWithInt:h] forKey: (NSString*)kCVPixelBufferHeightKey];
        [attributes setObject:@(linesize) forKey:(NSString*)kCVPixelBufferBytesPerRowAlignmentKey];
        [attributes setObject:[NSDictionary dictionary] forKey:(NSString*)kCVPixelBufferIOSurfacePropertiesKey];
        
        result = CVPixelBufferCreate(kCFAllocatorDefault,
                                     w,
                                     h,
                                     kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                                     (__bridge CFDictionaryRef)(attributes),
                                     &pixelBuffer);
    }
    
    if (kCVReturnSuccess == result) {
        int h = aFrame->height;
        CVPixelBufferLockBaseAddress(pixelBuffer,0);
        
        // Here y_src is Y-Plane of YUV(NV12) data.
        unsigned char *y_src  = aFrame->data[0];
        unsigned char *y_dest = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
        size_t y_dest_bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
        size_t y_src_bytesPerRow  = aFrame->linesize[0];
        
        for (int i = 0; i < h; i ++) {
            bzero(y_dest, y_dest_bytesPerRow);
            memcpy(y_dest, y_src, y_src_bytesPerRow);
            y_src  += y_src_bytesPerRow;
            y_dest += y_dest_bytesPerRow;
        }
        //memcpy(y_dest, y_src, bytePerRowY * h);
        
        // Here uv_src is UV-Plane of YUV(NV12) data.
        unsigned char *uv_src = aFrame->data[1];
        unsigned char *uv_dest = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
        size_t uv_dest_bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
        size_t uv_src_bytesPerRow  = aFrame->linesize[1];
        
        for (int i = 0; i <= h/2; i ++) {
            bzero(uv_dest, uv_dest_bytesPerRow);
            memcpy(uv_dest, uv_src, uv_src_bytesPerRow);
            uv_src  += uv_src_bytesPerRow;
            uv_dest += uv_dest_bytesPerRow;
        }
        //memcpy(uv_dest, uv_src, bytesPerRowUV * BYTE_ALIGN_2(h)/2);
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    }
    return pixelBuffer;
//    return (CVPixelBufferRef)CFAutorelease(pixelBuffer);
}

+ (UIImage *)imageFromCVPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    NSParameterAssert(pixelBuffer);
    CFRetain(pixelBuffer);
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
    CFRelease(pixelBuffer);
    return uiImage;
}

+ (UIImage *)imageFromAVFrameOverBitmap:(AVFrame*)aFrame
{
    NSParameterAssert(aFrame->format == AV_PIX_FMT_RGB24);
    
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
    UIImage *image = nil;
    if (cgImage) {
        image = [UIImage imageWithCGImage:cgImage];
        CGImageRelease(cgImage);
    }
    
    CGDataProviderRelease(provider);
    CFRelease(data);
    
    return image;
}

+ (UIImage *)imageFromAVFrameOverPixelBuffer:(AVFrame*)aFrame
{
    CVPixelBufferRef pixelBuffer = [self createCVPixelBufferFromAVFrame:aFrame];
    if (pixelBuffer) {
        UIImage *img = [self imageFromCVPixelBuffer:pixelBuffer];
        CFRelease(pixelBuffer);
        return img;
    }
    return nil;
}

#pragma mark - CVPixelBufferRef-->CMSampleBufferRef

+ (CMSampleBufferRef)createCMSampleBufferFromCVPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    if (pixelBuffer) {
        CFRetain(pixelBuffer);
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
        CFRelease(pixelBuffer);
        return sampleBuffer;//(CMSampleBufferRef)CFAutorelease(sampleBuffer);
    }
    return NULL;
}

@end
