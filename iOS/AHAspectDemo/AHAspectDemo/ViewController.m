//
//  ViewController.m
//  AHAspectDemo
//
//  Created by Alan Miu on 2017/5/12.
//  Copyright © 2017年 AutoHome. All rights reserved.
//

#import "ViewController.h"
#import "AHAspect.h"

@interface ViewController ()

@end

@implementation ViewController

+ (NSString *)description {
    return @"I'm a ViewController";
}

+ (NSUInteger)hash {
    return 12345;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeContactAdd];
    [btn setFrame:CGRectMake(100, 100, 40, 40)];
    [btn addTarget:self action:@selector(onClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    
    UIButton *btn1 = [UIButton buttonWithType:UIButtonTypeInfoDark];
    [btn1 setFrame:CGRectMake(100, 200, 40, 40)];
    [btn1 addTarget:self action:@selector(onClick1:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn1];
}

- (void)onClick:(UIButton *)btn {
    NSLog(@"btn + %@", [self send:@"Jack"]);
    [AHAspect setPointcutWithClass:[self class] selector:@selector(send:) advice:[AHAspectAdvice adviceWithInsteadBlock:^(AHAspectPoint *point) {
        NSLog(@"point: %@, arg: %@", point, [point arguments]);
        NSString *ret = @"ko";
        [point setReturnValue:&ret];
    }]];
    NSLog(@"btn + %@", [self send:@"Rose"]);
}

- (void)onClick1:(UIButton *)btn {
    NSLog(@"btn - %@", [self send:@"Jack"]);
    [AHAspect removePointcutWithClass:[self class] selector:@selector(send:)];
    NSLog(@"btn - %@", [self send:@"Rose"]);
}

- (NSString *)send:(NSString *)name {
    NSLog(@"hello %@", name);
    return @"ok";
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
