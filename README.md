# AHAspect

### Android Studio Plugin

* Build script snippet for use in all Gradle versions:

```
buildscript {
  repositories {
    maven {
      url "https://plugins.gradle.org/m2/"
    }
  }
  dependencies {
    classpath "gradle.plugin.com.autohome:ahaspect:1.0.0"
  }
}

apply plugin: "com.autohome.ahaspect"
```

* Build script snippet for new, incubating, plugin mechanism introduced in Gradle 2.1:

```
plugins {
    id "com.autohome.ahaspect" version "1.0.0" apply false
}

apply plugin: 'com.android.application'
apply plugin: 'com.autohome.ahaspect'
```


