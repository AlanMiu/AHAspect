//
//  TestAspect.m
//  AHAspectDemo
//
//  Created by Alan Miu on 2017/5/12.
//  Copyright © 2017年 AutoHome. All rights reserved.
//

#import "TestAspect.h"
#import "AHAspect.h"
#import <objc/runtime.h>

@implementation NSObject (TestAspect)

+ (void)load {
    
    // Hook类方法
    [AHAspect setPointcutWithClass:objc_getMetaClass("ViewController") selector:NSSelectorFromString(@"description") advice:[AHAspectAdvice adviceWithBeforeBlock:^(AHAspectPoint *point) {
        NSLog(@"AHAspects ViewController description");
    }]];
    
    // Hook实例方法
    [AHAspect setPointcutWithClass:NSClassFromString(@"ViewController") selector:NSSelectorFromString(@"viewDidLoad") advice:[AHAspectAdvice adviceWithBeforeBlock:^(AHAspectPoint *point) {
        NSLog(@"AHAspects ViewController viewDidLoad");
    }]];
}


@end
