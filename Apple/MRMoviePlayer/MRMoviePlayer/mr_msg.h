//
//  mr_msg.h
//  MRMoviePlayer
//
//  Created by qianlongxu on 2020/2/4.
//

#ifndef mr_msg_h
#define mr_msg_h

#include <stdio.h>

typedef enum MR_Msg_Type {
    MR_Msg_Type_InitVideoRender = 1,///可以初始化视频渲染
    MR_Msg_Type_InitAudioRender = 2,///可以初始化视频渲染
} MR_Msg_Type;

typedef struct MR_Msg{
    MR_Msg_Type type;
    int arg1;
    int arg2;
}MR_Msg;

#endif /* mr_msg_h */
