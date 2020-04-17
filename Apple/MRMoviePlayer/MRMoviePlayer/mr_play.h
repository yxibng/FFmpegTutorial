//
//  mr_play.h
//  MRMoviePlayer
//
//  Created by qianlongxu on 2020/1/31.
//

#ifndef mr_play_h
#define mr_play_h

#include <stdio.h>
#include "mr_msg.h"

typedef enum MRColorRange {
    MRCOL_RANGE_UNSPECIFIED = 0,
    MRCOL_RANGE_MPEG        = 1, ///< the normal 219*2^(n-8) "MPEG" YUV ranges
    MRCOL_RANGE_JPEG        = 2, ///< the normal     2^n-1   "JPEG" YUV ranges
    MRCOL_RANGE_NB               ///< Not part of ABI
}MRColorRange;

typedef enum MRPixelFormat{
    MR_PIX_FMT_NONE    = -1,
    MR_PIX_FMT_YUV420P = 1 << 0,    ///< planar YUV 4:2:0, 12bpp, (1 Cr & Cb sample per 2x2 Y samples)
    MR_PIX_FMT_NV12    = 1 << 1,    ///< planar YUV 4:2:0, 12bpp, 1 plane for Y and 1 plane for the UV components, which are in leaved (first byte U and the following byte V)
    MR_PIX_FMT_NV21    = 1 << 2,    ///< like NV12, but U and V bytes are swapped
    MR_PIX_FMT_RGB24   = 1 << 3     ///< packed RGB 8:8:8, 24bpp, RGBRGB...
}MRPixelFormat;

typedef struct MRPicture{
    /**
     * pointer to the picture/channel planes.
     * This might be different from the first allocated byte
     *
     * Some decoders access areas outside 0,0 - width,height, please
     * see avcodec_align_dimensions2(). Some filters and swscale can read
     * up to 16 bytes beyond the planes, if these filters are to be used,
     * then 16 extra bytes must be allocated.
     *
     * NOTE: Except for hwaccel formats, pointers not needed by the format
     * MUST be set to NULL.
     */
    uint8_t *data[8];

    /**
     * For video, size in bytes of each picture line.
     * For audio, size in bytes of each plane.
     *
     * For audio, only linesize[0] may be set. For planar audio, each channel
     * plane must be the same size.
     *
     * For video the linesizes should be multiples of the CPUs alignment
     * preference, this is 16 or 32 for modern desktop CPUs.
     * Some code requires such alignment other code can be slower without
     * correct alignment, for yet other it makes no difference.
     *
     * @note The linesize may be larger than the size of usable data -- there
     * may be extra padding present for performance reasons.
     */
    int linesize[8];
    int width, height;
    enum MRColorRange color_range;
    MRPixelFormat format;
}MRPicture;

typedef int (*DisplayFunc)(void *, MRPicture *); //(void *, AVFrame *)
typedef void(*MsgFunc)(void *, MR_Msg *);
typedef void * MRPlayer;

typedef enum MRSampleFormat{
    MR_SAMPLE_FMT_NONE = -1,
    MR_SAMPLE_FMT_S16  = 1 << 0,    ///< signed 16 bits
    MR_SAMPLE_FMT_FLT  = 1 << 1,    ///< float
    MR_SAMPLE_FMT_S16P = 1 << 2,    ///< signed 16 bits, planar
    MR_SAMPLE_FMT_FLTP = 1 << 3,    ///< float, planar
}MRSampleFormat;

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

///播放
int mr_play(MRPlayer opaque);
///暂停
int mr_pause(MRPlayer opaque);

///设置视频渲染回调函数
int mr_set_display_func(MRPlayer opaque, void *context, DisplayFunc func);
///获取交错形式的音频数据
int mr_fetch_packet_sample(MRPlayer opaque, uint8_t *buffer, int size);
///获取平面形式的音频数据
int mr_fetch_planar_sample(MRPlayer opaque, uint8_t *l_buffer, int l_size, uint8_t *r_buffer, int r_size);

#endif /* mr_play_h */
