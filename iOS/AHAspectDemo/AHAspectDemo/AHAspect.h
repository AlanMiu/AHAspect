//
//  AHAspect.h
//  AHKit
//
//  Created by Alan Miu on 2017/1/17.
//  Copyright © 2017年 AutoHome. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 切面点(获取参数和设置返回值)
 */
@interface AHAspectPoint : NSObject

@property (readonly) NSInvocation *invocation;

+ (instancetype)pointWithInvocation:(NSInvocation *)invocation;

- (void)setReturnValue:(void *)retLoc;

- (NSArray *)arguments;

@end

/**
 切面通知(设置切入点触发时的回调)
 */
@interface AHAspectAdvice : NSObject

typedef void (^advice_block_t)(AHAspectPoint *point);

@property (nonatomic, copy) advice_block_t beforeBlock;
@property (nonatomic, copy) advice_block_t afterBlock;
@property (nonatomic, copy) advice_block_t insteadBlock;

+ (instancetype)adviceWithBeforeBlock:(advice_block_t)before;
+ (instancetype)adviceWithAfterBlock:(advice_block_t)after;
+ (instancetype)adviceWithInsteadBlock:(advice_block_t)instead;

+ (instancetype)adviceWithBeforeBlock:(advice_block_t)before afterBlock:(advice_block_t)after insteadBlock:(advice_block_t)instead;

@end

@interface AHAspect : NSObject

/**
 设置切入点
 
 @param class class
 @param selector selector
 @param advice 切面通知
 */
+ (void)setPointcutWithClass:(Class)class selector:(SEL)selector advice:(AHAspectAdvice *)advice;

/**
 移除切入点
 
 @param class class
 @param selector selector
 */
+ (void)removePointcutWithClass:(Class)class selector:(SEL)selector;

@end


