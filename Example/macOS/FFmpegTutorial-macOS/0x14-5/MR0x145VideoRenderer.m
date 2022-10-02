//
//  MR0x145VideoRenderer.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/7/11.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x145VideoRenderer.h"
#import <OpenGL/gl.h>
#import <OpenGL/glext.h>
#import <AVFoundation/AVUtilities.h>
#import <GLKit/GLKit.h>
#import <MRFFmpegPod/libavutil/frame.h>
#import "MROpenGLHelper.h"
#import "MROpenGLCompiler.h"

// Uniform index.
enum
{
    UNIFORM_0,
    NUM_UNIFORMS
};

// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_TEXCOORD,
    NUM_ATTRIBUTES
};


@interface MR0x145VideoRenderer ()
{
    GLint uniforms[NUM_UNIFORMS];
    GLint attributers[NUM_ATTRIBUTES];
    GLuint plane_textures[NUM_UNIFORMS];
    MRViewContentMode _contentMode;
    CGRect _layerBounds;
}

@property MROpenGLCompiler * openglCompiler;;

@end

@implementation MR0x145VideoRenderer

- (void)dealloc
{
    glDeleteTextures(sizeof(plane_textures)/sizeof(GLuint), plane_textures);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        NSOpenGLPixelFormatAttribute attrs[] =
        {
            NSOpenGLPFAAccelerated,
            NSOpenGLPFANoRecovery,
            NSOpenGLPFADoubleBuffer,
            NSOpenGLPFADepthSize, 24,
            0
        };
        NSOpenGLPixelFormat *pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
        
        if (!pf)
        {
            NSLog(@"No OpenGL pixel format");
        }
        
        NSOpenGLContext* context = [[NSOpenGLContext alloc] initWithFormat:pf shareContext:nil];
        
    #if ESSENTIAL_GL_PRACTICES_SUPPORT_GL3 && defined(DEBUG)
        // When we're using a CoreProfile context, crash if we call a legacy OpenGL function
        // This will make it much more obvious where and when such a function call is made so
        // that we can remove such calls.
        // Without this we'd simply get GL_INVALID_OPERATION error for calling legacy functions
        // but it would be more difficult to see where that function was called.
        CGLEnable([context CGLContextObj], kCGLCECrashOnRemovedFunctions);
    #endif
        
        [self setPixelFormat:pf];
        [self setOpenGLContext:context];
    #if 1 || SUPPORT_RETINA_RESOLUTION
        // Opt-In to Retina resolution
        [self setWantsBestResolutionOpenGLSurface:YES];
    #endif // SUPPORT_RETINA_RESOLUTION
        
        [self drawInitBackgroundColor];
    }
    return self;
}

- (void)drawInitBackgroundColor
{
    [[self openGLContext] makeCurrentContext];
    CGLLockContext([[self openGLContext] CGLContextObj]);
    glClearColor(0.2,0.2,0.2,0.0);
    glClear(GL_COLOR_BUFFER_BIT);
    CGLFlushDrawable([[self openGLContext] CGLContextObj]);
    CGLUnlockContext([[self openGLContext] CGLContextObj]);
}

- (void)resetViewPort
{
    // We draw on a secondary thread through the display link. However, when
    // resizing the view, -drawRect is called on the main thread.
    // Add a mutex around to avoid the threads accessing the context
    // simultaneously when resizing.
    CGLLockContext([[self openGLContext] CGLContextObj]);
    
    // Get the view size in Points
    _layerBounds = [self bounds];
    
    NSRect viewRectPixels = [self convertRectToBacking:_layerBounds];
    
    GLsizei backingWidth = viewRectPixels.size.width;
    GLsizei backingHeight = viewRectPixels.size.height;
    // Set the new dimensions in our renderer
    glViewport(0, 0, backingWidth, backingHeight);
    
    CGLUnlockContext([[self openGLContext] CGLContextObj]);
}

- (void)setupOpenGLProgram
{
    if (!self.openglCompiler) {
        self.openglCompiler = [[MROpenGLCompiler alloc] initWithvshName:@"common.vsh" fshName:@"1_sampler2D.fsh"];
        
        if ([self.openglCompiler compileIfNeed]) {
            // Get uniform locations.
            uniforms[UNIFORM_0] = [self.openglCompiler getUniformLocation:"Sampler0"];
            
            attributers[ATTRIB_VERTEX] = [self.openglCompiler getAttribLocation:"position"];
            attributers[ATTRIB_TEXCOORD] = [self.openglCompiler getAttribLocation:"texCoord"];
        }
    }
}

- (void)initGL
{
    // The reshape function may have changed the thread to which our OpenGL
    // context is attached before prepareOpenGL and initGL are called.  So call
    // makeCurrentContext to ensure that our OpenGL context current to this
    // thread (i.e. makeCurrentContext directs all OpenGL calls on this thread
    // to [self openGLContext])
    [[self openGLContext] makeCurrentContext];
    
    // Synchronize buffer swaps with vertical refresh rate
    GLint swapInt = 1;
    [[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];
    
    [self setupOpenGLProgram];
    
    glDisable(GL_DEPTH_TEST);
    glEnable(GL_TEXTURE_2D);
    glGenTextures(sizeof(plane_textures)/sizeof(GLuint), plane_textures);
}

- (void)prepareOpenGL
{
    [super prepareOpenGL];

    // Make all the OpenGL calls to setup rendering
    //  and build the necessary rendering objects
    [self initGL];
}

- (void)reshape
{
    [super reshape];
    [self resetViewPort];
}

- (void)setContentMode:(MRViewContentMode)contentMode
{
    _contentMode = contentMode;
}

- (MRViewContentMode)contentMode
{
    return _contentMode;
}

- (void)uploadFrameToTexture:(AVFrame * _Nonnull)frame
{
    //设置纹理和采样器的对应关系
    glUniform1i(uniforms[UNIFORM_0], 0);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, plane_textures[0]);
    //internalformat 必须是 GL_RGBA，与创建 OpenGL 上下文指定的格式一样；
    //format 是当前数据的格式，可以是 GL_BGRA 也可以是 GL_RGBA，根据实际情况；但 CVPixelBufferRef 是不支持 RGBA 的；
    //这里指定好格式后，将会自动转换好对应关系，shader 无需做额外处理。
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, frame->width, frame->height, 0, GL_YCBCR_422_APPLE, GL_UNSIGNED_SHORT_8_8_APPLE, frame->data[0]);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
}

- (void)displayAVFrame:(AVFrame *)frame
{
    [[self openGLContext] makeCurrentContext];
    CGLLockContext([[self openGLContext] CGLContextObj]);
    
    glClearColor(0.0,0.0,0.0,0.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    [self.openglCompiler active];
    
    [self uploadFrameToTexture:frame];
    {
        GLsizei frameWidth = frame->width;
        GLsizei frameHeight = frame->height;
        // Compute normalized quad coordinates to draw the frame into.
        CGSize normalizedSamplingSize = CGSizeMake(1.0, 1.0);

        if (_contentMode == MRViewContentModeScaleAspectFit || _contentMode == MRViewContentModeScaleAspectFill) {
            // Set up the quad vertices with respect to the orientation and aspect ratio of the video.
            CGRect vertexSamplingRect = AVMakeRectWithAspectRatioInsideRect(CGSizeMake(frameWidth, frameHeight), _layerBounds);

            CGSize cropScaleAmount = CGSizeMake(vertexSamplingRect.size.width/_layerBounds.size.width, vertexSamplingRect.size.height/_layerBounds.size.height);

            // hold max
            if (_contentMode == MRViewContentModeScaleAspectFit) {
                if (cropScaleAmount.width > cropScaleAmount.height) {
                    normalizedSamplingSize.width = 1.0;
                    normalizedSamplingSize.height = cropScaleAmount.height/cropScaleAmount.width;
                }
                else {
                    normalizedSamplingSize.height = 1.0;
                    normalizedSamplingSize.width = cropScaleAmount.width/cropScaleAmount.height;
                }
            } else if (_contentMode == MRViewContentModeScaleAspectFill) {
                // hold min
                if (cropScaleAmount.width > cropScaleAmount.height) {
                    normalizedSamplingSize.height = 1.0;
                    normalizedSamplingSize.width = cropScaleAmount.width/cropScaleAmount.height;
                }
                else {
                    normalizedSamplingSize.width = 1.0;
                    normalizedSamplingSize.height = cropScaleAmount.height/cropScaleAmount.width;
                }
            }
        }
        
        /*
         The quad vertex data defines the region of 2D plane onto which we draw our pixel buffers.
         Vertex data formed using (-1,-1) and (1,1) as the bottom left and top right coordinates respectively, covers the entire screen.
         */
        GLfloat quadVertexData [] = {
            -1 * normalizedSamplingSize.width, -1 * normalizedSamplingSize.height,
            normalizedSamplingSize.width, -1 * normalizedSamplingSize.height,
            -1 * normalizedSamplingSize.width, normalizedSamplingSize.height,
            normalizedSamplingSize.width, normalizedSamplingSize.height,
        };
        
        // 更新顶点数据
        glVertexAttribPointer(attributers[ATTRIB_VERTEX], 2, GL_FLOAT, 0, 0, quadVertexData);
        glEnableVertexAttribArray(attributers[ATTRIB_VERTEX]);
    }
    
    {
        GLfloat quadTextureData[] = { // 坐标不对可能导致画面显示方向不对
            0, 1,
            1, 1,
            0, 0,
            1, 0,
        };
        
        glVertexAttribPointer(attributers[ATTRIB_TEXCOORD], 2, GL_FLOAT, 0, 0, quadTextureData);
        glEnableVertexAttribArray(attributers[ATTRIB_TEXCOORD]);
    }
    VerifyGL(;);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    CGLFlushDrawable([[self openGLContext] CGLContextObj]);
    CGLUnlockContext([[self openGLContext] CGLContextObj]);
}

@end
