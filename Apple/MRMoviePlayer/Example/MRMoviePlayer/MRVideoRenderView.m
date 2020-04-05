//
//  MRVideoRenderView.m
//  MRMoviePlayer
//
//  Created by Matt Reach on 2019/1/28.
//  Copyright © 2019 Awesome FFmpeg Study Demo. All rights reserved.
//

#import "MRVideoRenderView.h"
#import <AVFoundation/AVSampleBufferDisplayLayer.h>
#import <CoreVideo/CVPixelBufferPool.h>
#import "MRConvertUtil.h"

@interface MRVideoRenderView ()

//PixelBuffer池可提升效率
@property (assign, nonatomic) CVPixelBufferPoolRef pixelBufferPool;

@end

@implementation MRVideoRenderView

+ (Class)layerClass
{
    return [AVSampleBufferDisplayLayer class];
}

- (void)dealloc
{
    if(self.pixelBufferPool){
        CVPixelBufferPoolRelease(self.pixelBufferPool);
        self.pixelBufferPool = NULL;
    }
}

- (void)_init {
    self.layer.opaque = YES;
    self.layer.backgroundColor = [UIColor blackColor].CGColor;
    self.usePool = YES;
    [self setContentMode:UIViewContentModeScaleToFill];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self _init];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self _init];
    }
    return self;
}

- (void)setContentMode:(UIViewContentMode)contentMode
{
    switch (contentMode) {
        case UIViewContentModeScaleAspectFill:
        {
            AVSampleBufferDisplayLayer *layer = (AVSampleBufferDisplayLayer *)[self layer];
            layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        }
            break;
        case UIViewContentModeScaleAspectFit:
        {
            AVSampleBufferDisplayLayer *layer = (AVSampleBufferDisplayLayer *)[self layer];
            layer.videoGravity = AVLayerVideoGravityResizeAspect;
        }
            break;
        default:
        {
            AVSampleBufferDisplayLayer *layer = (AVSampleBufferDisplayLayer *)[self layer];
            layer.videoGravity = AVLayerVideoGravityResize;
        }
            break;
    }
}

- (UIViewContentMode)contentMode
{
    AVSampleBufferDisplayLayer *layer = (AVSampleBufferDisplayLayer *)[self layer];
    
    if ([AVLayerVideoGravityResizeAspect isEqualToString:layer.videoGravity]) {
        return UIViewContentModeScaleAspectFit;
    } else if ([AVLayerVideoGravityResizeAspectFill isEqualToString:layer.videoGravity]){
        return UIViewContentModeScaleAspectFill;
    } else {
        return UIViewContentModeScaleToFill;
    }
}

- (CMSampleBufferRef)createSampleBufferFromAVFrame:(AVFrame*)frame
{
    if (self.usePool) {
        CVReturn theError;
        if (!self.pixelBufferPool){
            int linesize = 32;//frame->linesize[0];
            int w = frame->width;
            int h = frame->height;
            
            NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
            [attributes setObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
            [attributes setObject:[NSNumber numberWithInt:w] forKey: (NSString*)kCVPixelBufferWidthKey];
            [attributes setObject:[NSNumber numberWithInt:h] forKey: (NSString*)kCVPixelBufferHeightKey];
            [attributes setObject:@(linesize) forKey:(NSString*)kCVPixelBufferBytesPerRowAlignmentKey];
            [attributes setObject:[NSDictionary dictionary] forKey:(NSString*)kCVPixelBufferIOSurfacePropertiesKey];
            
            theError = CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef) attributes, &_pixelBufferPool);
            if (theError != kCVReturnSuccess){
                NSLog(@"CVPixelBufferPoolCreate Failed");
            }
        }
    }
    
    CVPixelBufferRef pixelBuffer = [MRConvertUtil createCVPixelBufferFromAVFrame:frame opt:self.pixelBufferPool];
    
    if (pixelBuffer) {
        CMSampleBufferRef buffer = [MRConvertUtil createCMSampleBufferFromCVPixelBuffer:pixelBuffer];
        CFRelease(pixelBuffer);
        return buffer;
    }
    return NULL;
}

- (void)enqueueSampleBuffer:(CMSampleBufferRef)buffer
{
    AVSampleBufferDisplayLayer *layer = (AVSampleBufferDisplayLayer *)[self layer];
    [layer enqueueSampleBuffer:buffer];
}

- (void)enqueueAVFrame:(AVFrame *)aFrame
{
    CMSampleBufferRef sampleBuffer = [self createSampleBufferFromAVFrame:aFrame];
    
    if (sampleBuffer) {
        if ((dispatch_queue_get_label(dispatch_get_main_queue()) == dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL))) {
            [self enqueueSampleBuffer:sampleBuffer];
        } else {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self enqueueSampleBuffer:sampleBuffer];
            });
        }
        CFRelease(sampleBuffer);
    }
}

@end
