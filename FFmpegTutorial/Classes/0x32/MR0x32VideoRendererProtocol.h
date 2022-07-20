//
//  MR0x32VideoRendererProtocol.h
//  Pods
//
//  Created by qianlongxu on 2022/7/20.
//

#ifndef MR0x32VideoRendererProtocol_h
#define MR0x32VideoRendererProtocol_h

typedef enum : NSUInteger {
    MR0x32ContentModeScaleToFill,
    MR0x32ContentModeScaleAspectFill,
    MR0x32ContentModeScaleAspectFit
} MR0x32ContentMode;

@protocol MR0x32VideoRendererProtocol <NSObject>

- (void)setContentMode:(MR0x32ContentMode)contentMode;
- (MR0x32ContentMode)contentMode;

@end

#endif /* MR0x32VideoRendererProtocol_h */
