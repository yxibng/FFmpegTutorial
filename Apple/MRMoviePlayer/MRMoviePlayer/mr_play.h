//
//  mr_play.h
//  MRMoviePlayer
//
//  Created by qianlongxu on 2020/1/31.
//

#ifndef mr_play_h
#define mr_play_h

#include <stdio.h>
#include <libavutil/frame.h>
#include "mr_msg.h"

typedef int (*DisplayFunc)(void *, AVFrame *);
typedef void(*MsgFunc)(void *, MR_Msg *);
typedef void * MRPlayer;

typedef enum MRSampleFormat{
    MR_SAMPLE_FMT_NONE = -1,
    MR_SAMPLE_FMT_S16 = 1 << 0,         ///< signed 16 bits
    MR_SAMPLE_FMT_FLT = 1 << 1,         ///< float
    MR_SAMPLE_FMT_S16P = 1 << 2,        ///< signed 16 bits, planar
    MR_SAMPLE_FMT_FLTP = 1 << 3,        ///< float, planar
}MRSampleFormat;

typedef enum MRPixelFormat{
    MR_PIX_FMT_NONE = -1,
    MR_PIX_FMT_YUV420P = 1 << 0,   ///< planar YUV 4:2:0, 12bpp, (1 Cr & Cb sample per 2x2 Y samples)
    MR_PIX_FMT_NV12 = 1 << 1,      ///< planar YUV 4:2:0, 12bpp, 1 plane for Y and 1 plane for the UV components, which are interleaved (first byte U and the following byte V)
    MR_PIX_FMT_NV21 = 1 << 2,      ///< like NV12, but U and V bytes are swapped
}MRPixelFormat;

static inline int mr_sample_fmt_is_planar(MRSampleFormat sample_fmt){
    if (sample_fmt == MR_SAMPLE_FMT_S16P || sample_fmt == MR_SAMPLE_FMT_FLTP) {
        return 1;
    } else {
        return 0;
    }
}

typedef struct mr_init_params{
    const char *url;
    MsgFunc msg_func;
    void *msg_func_ctx;
    ///传入支持的音频采样率和格式，好让播放器决定是否需要重采样
    int supported_sample_fmts;
    int supported_sample_rate;
    ///传入支持的视频像素格式格式，好让播放器决定是否需要转换格式
    int supported_pixel_fmts;
}mr_init_params;

///创建播放器实例
MRPlayer mr_player_instance_create(mr_init_params *params);
///准备播放
int mr_prepare_play(MRPlayer opaque);
///设置视频渲染回调函数
int mr_set_display_func(MRPlayer opaque, void *context, DisplayFunc func);

int mr_fetch_packet_sample(MRPlayer opaque, uint8_t *buffer, int size);
int mr_fetch_planar_sample(MRPlayer opaque, uint8_t *l_buffer, int l_size, uint8_t *r_buffer, int r_size);

#endif /* mr_play_h */
