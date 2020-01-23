//
//  ViewController.m
//  MRStreamProber
//
//  Created by qianlongxu on 2020/1/19.
//  Copyright © 2020 Awesome FFmpeg Study Demo. All rights reserved.
//

#import "ViewController.h"
#import "MRStreamProber.hpp"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    MRStreamProber prober;
    prober.init();
    
    const char *url = "http://debugly.cn/repository/test.mp4";
    const char *result = NULL;
    if (0 == prober.probe(url,&result)) {
        printf("%s",result);
        free((void *)result);
        result = NULL;
    }
    prober.destroy();
}

@end
