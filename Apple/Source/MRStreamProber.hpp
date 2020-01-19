//
//  MRStreamProber.hpp
//  MRStreamProber
//
//  Created by qianlongxu on 2020/1/19.
//  Copyright © 2020 Awesome FFmpeg Study Demo. All rights reserved.
//

#ifndef MRStreamProber_hpp
#define MRStreamProber_hpp

#include <stdio.h>

class MRStreamProber {
    
public:
    void init();
    int probe(const char* url,const char **result);
    void destroy();
};

#endif /* MRStreamProber_hpp */
