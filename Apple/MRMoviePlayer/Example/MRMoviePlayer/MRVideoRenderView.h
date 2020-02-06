//
//  MRVideoRenderView.h
//  MRMoviePlayer
//
//  Created by Matt Reach on 2019/1/28.
//  Copyright © 2019 Awesome FFmpeg Study Demo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreMedia/CMSampleBuffer.h>
#import <libavutil/frame.h>

//only support MR_PIX_FMT_NV12/AV_PIX_FMT_NV12

@interface MRVideoRenderView : UIView
///default is true.
@property (nonatomic, assign) BOOL usePool;
///only main queue
- (void)enqueueSampleBuffer:(CMSampleBufferRef)buffer;
///can invoke from any queue
- (void)enqueueAVFrame:(AVFrame*)aFrame;

@end
