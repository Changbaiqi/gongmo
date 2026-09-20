# ============================================================
# R8 / ProGuard 规则
#
# flutter_local_notifications 用 Gson 序列化「定时通知」，R8 裁剪泛型签名后
# ScheduledNotificationReceiver 反序列化会抛：
#   IllegalStateException: TypeToken must be created with a type argument...
# 导致每日提醒触发（或应用启动恢复定时通知）时进程闪退。
# ============================================================

# 保留泛型签名与注解（Gson 反射依赖）
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Gson：TypeToken 及其匿名子类必须完整保留
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken { *; }
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-dontwarn sun.misc.**
-dontwarn com.google.gson.**

# flutter_local_notifications：定时通知的序列化模型与接收器
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.** { *; }
