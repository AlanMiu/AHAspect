package com.autohome.ahaspectdemo;

import android.util.Log;

import org.aspectj.lang.JoinPoint;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Before;
import org.aspectj.lang.annotation.Pointcut;

/**
 * Created by Alan on 2017/5/10.
 */

@Aspect
public class TestAspect {
    private String TAG = "AHAspect";

    private static final String POINT_METHOD_CALL = "call(* com.autohome.ahaspectdemo.MainActivity.*(..))";
    private static final String POINT_METHOD_EXEC = "execution(* com.autohome.ahaspectdemo.MainActivity.*(..))";


    @Pointcut(POINT_METHOD_CALL)
    public void methodCall(){}
    @Pointcut(POINT_METHOD_EXEC)
    public void methodExec(){}

    @Around("methodCall()")
    public Object around(ProceedingJoinPoint joinPoint) throws Throwable {
        Log.e(TAG, "### aronud: " + joinPoint.getSourceLocation());
        return joinPoint.proceed();
    }
    @Before("methodExec()")
    public void before(JoinPoint joinPoint){
        Log.e(TAG, "### before: " + joinPoint.getSourceLocation());
    }

}