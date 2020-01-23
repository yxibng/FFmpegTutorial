//
//  MRStreamProber.cpp
//  MRStreamProber
//
//  Created by qianlongxu on 2020/1/19.
//  Copyright © 2020 Awesome FFmpeg Study Demo. All rights reserved.
//

#include "MRStreamProber.hpp"

extern "C"{
    #include <libavformat/avformat.h>
    #include <libavutil/pixdesc.h>
}

void MRStreamProber::init(){
    ///初始化libavformat，注册所有文件格式，编解码库；这不是必须的，如果你能确定需要打开什么格式的文件，使用哪种编解码类型，也可以单独注册！
    av_register_all();
    avformat_network_init();
}

int MRStreamProber::probe(const char *url,const char **result){
    AVFormatContext *formatCtx = NULL;
    
    if (0 != avformat_open_input(&formatCtx, url, NULL, NULL)) {
        avformat_close_input(&formatCtx);
        printf("can't open input:%s",url);
        return -1;
    }
    
    formatCtx->probesize = 500 * 1024;
    formatCtx->max_analyze_duration = 5 * AV_TIME_BASE;
    
    if (0 != avformat_find_stream_info(formatCtx, NULL)) {
        avformat_close_input(&formatCtx);
        printf("can't find stream info for input:%s",url);
        return -2;
    } else {
        
        char *str = (char *)av_calloc(1, 1024);
        
        //遍历所有的流
        for (int i = 0; i < formatCtx->nb_streams; i++) {
            
            AVStream *stream = formatCtx->streams[i];
            
            AVCodecContext *codecCtx = avcodec_alloc_context3(NULL);
            if (!codecCtx){
                continue;
            }
            
            int ret = avcodec_parameters_to_context(codecCtx, stream->codecpar);
            if (ret < 0){
                avcodec_free_context(&codecCtx);
                continue;
            }
            
            av_codec_set_pkt_timebase(codecCtx, stream->time_base);
            
            //AVCodecContext *codec = stream->codec;
            enum AVMediaType codec_type = codecCtx->codec_type;
            switch (codec_type) {
                    ///音频流
                case AVMEDIA_TYPE_AUDIO:
                {
                    //采样率
                    int sample_rate = codecCtx->sample_rate;
                    //声道数
                    int channels = codecCtx->channels;
                    //平均比特率
                    int64_t brate = codecCtx->bit_rate;
                    //时长
                    int64_t duration = stream->duration;
                    //解码器id
                    enum AVCodecID codecID = codecCtx->codec_id;
                    //根据解码器id找到对应名称
                    const char *codecDesc = avcodec_get_name(codecID);
                    //音频采样格式
                    enum AVSampleFormat format = codecCtx->sample_fmt;
                    //获取音频采样格式名称
                    const char * formatDesc = av_get_sample_fmt_name(format);
                    
                    sprintf(str + strlen(str),"\n\nAudio:\n%d Kbps，%.1f KHz， %d channels，%s，%s，duration:%lld",(int)(brate/1000.0),sample_rate/1000.0,channels,codecDesc,formatDesc,duration);
                }
                    break;
                    ///视频流
                case AVMEDIA_TYPE_VIDEO:
                {
                    ///画面宽度，单位像素
                    int vwidth = codecCtx->width;
                    ///画面高度，单位像素
                    int vheight = codecCtx->height;
                    //比特率
                    int64_t brate = codecCtx->bit_rate;
                    //解码器id
                    enum AVCodecID codecID = codecCtx->codec_id;
                    //根据解码器id找到对应名称
                    const char *codecDesc = avcodec_get_name(codecID);
                    //视频像素格式
                    enum AVPixelFormat format = codecCtx->pix_fmt;
                    //获取视频像素格式名称
                    const char * formatDesc = av_get_pix_fmt_name(format);
                    ///帧率
                    float fps, timebase = 0.04;
                    if (stream->time_base.den && stream->time_base.num) {
                        timebase = av_q2d(stream->time_base);
                    }
                    
                    if (stream->avg_frame_rate.den && stream->avg_frame_rate.num) {
                        fps = av_q2d(stream->avg_frame_rate);
                    }else if (stream->r_frame_rate.den && stream->r_frame_rate.num){
                        fps = av_q2d(stream->r_frame_rate);
                    }else{
                        fps = 1.0 / timebase;
                    }
                    
                    sprintf(str + strlen(str),"\n\nVideo:\n%dKbps，%d*%d，at %.3fps， %s， %s",(int)(brate/1024.0),vwidth,vheight,fps,codecDesc,formatDesc);
                }
                    break;
                case AVMEDIA_TYPE_ATTACHMENT:
                {
                    printf("附加信息流:%d",i);
                }
                    break;
                default:
                {
                    printf("其他流:%d",i);
                }
                    break;
            }
        }
        
        avformat_close_input(&formatCtx);
        
        if (result) {
            *result = str;
        } else {
            av_freep(str);
        }
        
        return 0;
    }
}

void MRStreamProber::destroy(){
    avformat_network_deinit();
}
