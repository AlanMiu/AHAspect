//
//  AHAspect.m
//  AHKit
//
//  Created by Alan Miu on 2017/1/17.
//  Copyright © 2017年 AutoHome. All rights reserved.
//

#import "AHAspect.h"
#import <objc/runtime.h>
#import <objc/message.h>

#define IS_STRET(cls, sel) ([cls instanceMethodSignatureForSelector:sel].methodReturnLength > sizeof(double))
#define SWIZZLED_SELECTOR(sel) NSSelectorFromString([@"_a_h_a_s_p_e_c_t_" stringByAppendingString:NSStringFromSelector(sel)])

#define CLASS_GET_METHOD(cls, sel) (class_isMetaClass(cls) ? class_getClassMethod(cls, sel) : class_getInstanceMethod(cls, sel))

#define CREATE_ADVICE_KEY(cls, sel) [NSString stringWithFormat:@"%@%@%@", NSStringFromClass(cls), (class_isMetaClass(cls) ? @"+" : @"-"),  NSStringFromSelector(sel)]
#define CREATE_CLASS_KEY(cls) [NSString stringWithFormat:@"%@%@", NSStringFromClass(cls), (class_isMetaClass(cls) ? @"+" : @"-")]

#if defined(__arm64__)
#   define OBJC_MSGFORWARD_IMP(cls, sel) _objc_msgForward
#   define CLASS_GET_IMPLEMENTATION(cls, sel) class_getMethodImplementation(cls, sel)
#else
#   define OBJC_MSGFORWARD_IMP(cls, sel) (IS_STRET(cls, sel) ? _objc_msgForward_stret : _objc_msgForward)
#   define CLASS_GET_IMPLEMENTATION(cls, sel) (IS_STRET(cls, sel) ? class_getMethodImplementation_stret(cls, sel) : class_getMethodImplementation(cls, sel))
#endif

@interface NSInvocation (AHAspect)
- (NSArray *)ahaspect_arguments;
@end

/**
 切面点(获取参数和设置返回值)
 */
@implementation AHAspectPoint

+ (instancetype)pointWithInvocation:(NSInvocation *)invocation {
    AHAspectPoint *point = [AHAspectPoint new];
    [point setInvocation:invocation];
    
    return point;
}

- (void)setInvocation:(NSInvocation *)invocation {
    _invocation = invocation;
}

/**
 设置返回值

 @param retLoc 对象指针
 */
- (void)setReturnValue:(void *)retLoc {
    if (_invocation)
        [_invocation setReturnValue:retLoc];
}

/**
 获取参数

 @return 调用时的参数
 */
- (NSArray *)arguments {
    if (_invocation)
        return [_invocation ahaspect_arguments];
     return nil;
}

@end


/**
 切面通知(设置切入点触发时的回调)
 */
@implementation AHAspectAdvice

+ (instancetype)adviceWithBeforeBlock:(advice_block_t)before {
    return [AHAspectAdvice adviceWithBeforeBlock:before afterBlock:nil insteadBlock:nil];
}

+ (instancetype)adviceWithAfterBlock:(advice_block_t)after {
    return [AHAspectAdvice adviceWithBeforeBlock:nil afterBlock:after insteadBlock:nil];
}

+ (instancetype)adviceWithInsteadBlock:(advice_block_t)instead {
    return [AHAspectAdvice adviceWithBeforeBlock:nil afterBlock:nil insteadBlock:instead];
}

+ (instancetype)adviceWithBeforeBlock:(advice_block_t)before afterBlock:(advice_block_t)after insteadBlock:(advice_block_t)instead {
    AHAspectAdvice *advice = [AHAspectAdvice new];
    advice.beforeBlock = before;
    advice.afterBlock = after;
    advice.insteadBlock = instead;
    
    return advice;
}

@end


/**
 AHAspect
 */
@implementation AHAspect {
    NSLock *_aspectLock;
    NSMutableDictionary *_aspectStore;
}

static id _ahaspect;
+ (instancetype)sharedAspect {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _ahaspect = [[self alloc] init];
    });
    return _ahaspect;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _ahaspect = [super allocWithZone:zone];
    });
    return _ahaspect;
}

+ (void)setPointcutWithClass:(Class)class selector:(SEL)selector advice:(AHAspectAdvice *)advice {
    [[AHAspect sharedAspect] setPointcutWithClass:class selector:selector advice:advice];
}

+ (void)removePointcutWithClass:(Class)class selector:(SEL)selector {
    [[AHAspect sharedAspect] removePointcutWithClass:class selector:selector];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        if (!_aspectStore) {
            _aspectLock = [NSLock new];
            _aspectStore = [NSMutableDictionary dictionary];
        }
    }
    return self;
}

/**
 设置切入点

 @param class class
 @param selector selector
 @param advice 切面通知
 */
- (void)setPointcutWithClass:(Class)class selector:(SEL)selector advice:(AHAspectAdvice *)advice {
    NSParameterAssert(class);
    NSParameterAssert(selector);
    NSParameterAssert(advice);

    [_aspectLock lock];
    [self swizzledForwardInvocationWithClass:class];
    [self forwardingMethodWithClass:class selector:selector advice:advice];
    [_aspectLock unlock];
}

/**
 移除切入点

 @param class class
 @param selector selector
 */
- (void)removePointcutWithClass:(Class)class selector:(SEL)selector {
    NSParameterAssert(class);
    NSParameterAssert(selector);
    
    [_aspectLock lock];
    [self restoreMethodWithClass:class selector:selector];
    [_aspectLock unlock];
}

/**
 替换消息转发方法

 @param class class
 */
- (void)swizzledForwardInvocationWithClass:(Class)class {
    if ([self isSwizzledWhitClass:class])
        return;

    SEL originalSelector = @selector(forwardInvocation:);
    SEL swizzledSelector = @selector(_ahaspect_forwardInvocation:);
    // 添加替换的消息转发方法
    Method swizzledMethod = class_getInstanceMethod([self class], swizzledSelector);
    class_addMethod(class, swizzledSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
    
    // 交换原消息转发方法和替换消息转发方法的实现(IMP)
    method_exchangeImplementations(CLASS_GET_METHOD(class, originalSelector), CLASS_GET_METHOD(class, swizzledSelector));

    [self setSwizzledWhitClass:class];
}

/**
 转发方法实现

 @param class class
 @param selector selector
 @param advice 切面通知
 */
- (void)forwardingMethodWithClass:(Class)class selector:(SEL)selector advice:(AHAspectAdvice *)advice {
    // 设置方法切面通知
    [self setAdvice:advice forClass:class andSelector:selector];
    
    // 检查方式现实是否已设置消息转发
    IMP originalImplementation = CLASS_GET_IMPLEMENTATION(class, selector);
    if (originalImplementation == OBJC_MSGFORWARD_IMP(class, selector))
        return;
    
    // 获取原方法信息
    Method originalMethod = CLASS_GET_METHOD(class, selector);
    const char *typeEncoding = method_getTypeEncoding(originalMethod);
    // 添加替换方法
    class_addMethod(class, SWIZZLED_SELECTOR(selector), originalImplementation, typeEncoding);
    // 设置原方法实现为消息转发, 触发消息转发方法(forwardInvocation:)
    method_setImplementation(originalMethod, OBJC_MSGFORWARD_IMP(class, selector));
    
}

/**
 恢复方法实现

 @param class class
 @param selector selector
 */
- (void)restoreMethodWithClass:(Class)class selector:(SEL)selector {
    // 移除方法切面通知
    [self removeAdviceForClass:class andSelector:selector];
    // 检查替换选择器是否存在
    SEL swizzledSelector = SWIZZLED_SELECTOR(selector);
    if (!CLASS_GET_METHOD(class, swizzledSelector))
        return;
    // 恢复原方法的实现
    IMP originalImplementation = CLASS_GET_IMPLEMENTATION(class, swizzledSelector);
    method_setImplementation(CLASS_GET_METHOD(class, selector), originalImplementation);
}

/**
 设置类中的消息转发方法替换完成

 @param class class
 */
- (void)setSwizzledWhitClass:(Class)class {
    NSString *classKey = CREATE_CLASS_KEY(class);
    Method selfForwardInvocationMethod = CLASS_GET_METHOD(class, @selector(forwardInvocation:));
    Method superForwardInvocationMethod = CLASS_GET_METHOD([class superclass], @selector(forwardInvocation:));
    BOOL isOverrideForwardInvocation = selfForwardInvocationMethod != superForwardInvocationMethod;
    [_aspectStore setObject:[NSNumber numberWithBool:isOverrideForwardInvocation] forKey:classKey];
}

/**
 类中的消息转发方法是否已经替换完成

 @param class class
 @return 是否替换
 */
- (BOOL)isSwizzledWhitClass:(Class)class {
    NSString *classKey = CREATE_CLASS_KEY(class);
    return [_aspectStore objectForKey:classKey] != nil;
}

/**
 类中是否有重写消息转发方法

 @param class class
 @return 是否重写
 */
- (BOOL)isOverrideForwardInvocationWhitClass:(Class)class {
    NSString *classKey = CREATE_CLASS_KEY(class);
    return [[_aspectStore objectForKey:classKey] boolValue];
}

/**
 设置切面通知

 @param advice 切面通知
 @param class class
 @param selector selector
 */
- (void)setAdvice:(AHAspectAdvice *)advice forClass:(Class)class andSelector:(SEL)selector {
    NSString *adviceKey = CREATE_ADVICE_KEY(class, selector);
    [_aspectStore setObject:advice forKey:adviceKey];
}


/**
 移除切面通知

 @param class class
 @param selector selector
 */
- (void)removeAdviceForClass:(Class)class andSelector:(SEL)selector {
    NSString *adviceKey = CREATE_ADVICE_KEY(class, selector);
    [_aspectStore removeObjectForKey:adviceKey];
}


/**
 获取切面通知
 
 @param class class
 @param selector selector
 @return 切面通知
 */
- (AHAspectAdvice *)adviceForClass:(Class)class andSelector:(SEL)selector {
    NSString *adviceKey = CREATE_ADVICE_KEY(class, selector);
    return [_aspectStore objectForKey:adviceKey];
}

/**
 执行切面通知

 @param anInvocation anInvocation
 @return 类中消息转发是否被重写
 */
- (BOOL)performAdviceWithInvocation:(NSInvocation *)anInvocation {
    if (!anInvocation)
        return NO;
    
    Class class = [anInvocation.target class];
    if (object_isClass(anInvocation.target))
        class = objc_getMetaClass(NSStringFromClass(class).UTF8String);
    
    AHAspectAdvice *advice = [[AHAspect sharedAspect] adviceForClass:class andSelector:anInvocation.selector];
    if (advice) {
        if (advice.beforeBlock)
            advice.beforeBlock([AHAspectPoint pointWithInvocation:anInvocation]);
        
        if (advice.insteadBlock) {
            advice.insteadBlock([AHAspectPoint pointWithInvocation:anInvocation]);
        } else {
            [anInvocation setSelector:SWIZZLED_SELECTOR(anInvocation.selector)];
            [anInvocation invoke];
        }
        
        if (advice.afterBlock)
            advice.afterBlock([AHAspectPoint pointWithInvocation:anInvocation]);
        
        return [self isOverrideForwardInvocationWhitClass:class];
    }
    
    return NO;
}

/**
 消息转发方法替身

 @param anInvocation anInvocation
 */
- (void)_ahaspect_forwardInvocation:(NSInvocation *)anInvocation {
    if ([[AHAspect sharedAspect] performAdviceWithInvocation:anInvocation]) {
        [self _ahaspect_forwardInvocation:anInvocation];
    }
}

@end


@implementation NSInvocation (AHAspect)

- (NSArray *)ahaspect_arguments {
    NSUInteger argCount = self.methodSignature.numberOfArguments;
    NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:argCount];
    for (NSUInteger index = 2; index < argCount; index++) {
        [arguments addObject:[self ahaspect_argumentAtIndex:index] ?: NSNull.null];
    }
    return [arguments copy];
}

- (id)ahaspect_argumentAtIndex:(NSUInteger)index {
    const char *argType = [self.methodSignature getArgumentTypeAtIndex:index];
    // Skip const type qualifier.
    if (argType[0] == _C_CONST)
        argType++;
    
    #define WRAP_AND_RETURN(type) do { type val = 0; [self getArgument:&val atIndex:(NSInteger)index]; return @(val);} while (0)
    if (strcmp(argType, @encode(id)) == 0 || strcmp(argType, @encode(Class)) == 0) {
        __autoreleasing id returnObj;
        [self getArgument:&returnObj atIndex:(NSInteger)index];
        return returnObj;
    } else if (strcmp(argType, @encode(SEL)) == 0) {
        SEL selector = 0;
        [self getArgument:&selector atIndex:(NSInteger)index];
        return NSStringFromSelector(selector);
    } else if (strcmp(argType, @encode(char)) == 0) {
        WRAP_AND_RETURN(char);
    } else if (strcmp(argType, @encode(int)) == 0) {
        WRAP_AND_RETURN(int);
    } else if (strcmp(argType, @encode(short)) == 0) {
        WRAP_AND_RETURN(short);
    } else if (strcmp(argType, @encode(long)) == 0) {
        WRAP_AND_RETURN(long);
    } else if (strcmp(argType, @encode(long long)) == 0) {
        WRAP_AND_RETURN(long long);
    } else if (strcmp(argType, @encode(unsigned char)) == 0) {
        WRAP_AND_RETURN(unsigned char);
    } else if (strcmp(argType, @encode(unsigned int)) == 0) {
        WRAP_AND_RETURN(unsigned int);
    } else if (strcmp(argType, @encode(unsigned short)) == 0) {
        WRAP_AND_RETURN(unsigned short);
    } else if (strcmp(argType, @encode(unsigned long)) == 0) {
        WRAP_AND_RETURN(unsigned long);
    } else if (strcmp(argType, @encode(unsigned long long)) == 0) {
        WRAP_AND_RETURN(unsigned long long);
    } else if (strcmp(argType, @encode(float)) == 0) {
        WRAP_AND_RETURN(float);
    } else if (strcmp(argType, @encode(double)) == 0) {
        WRAP_AND_RETURN(double);
    } else if (strcmp(argType, @encode(BOOL)) == 0) {
        WRAP_AND_RETURN(BOOL);
    } else if (strcmp(argType, @encode(char *)) == 0) {
        WRAP_AND_RETURN(const char *);
    } else if (strcmp(argType, @encode(void (^)(void))) == 0) {
        __unsafe_unretained id block = nil;
        [self getArgument:&block atIndex:(NSInteger)index];
        return [block copy];
    } else {
        NSUInteger valueSize = 0;
        NSGetSizeAndAlignment(argType, &valueSize, NULL);
        
        unsigned char valueBytes[valueSize];
        [self getArgument:valueBytes atIndex:(NSInteger)index];
        
        return [NSValue valueWithBytes:valueBytes objCType:argType];
    }
    #undef WRAP_AND_RETURN
    return nil;
}

@end

