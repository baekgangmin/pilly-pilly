# TensorFlow Lite Keep Rules
-keep class org.tensorflow.** { *; }
-keep class com.ultralytics.** { *; }
-keepclassmembers class * {
    native <methods>;
}
-keepclassmembers class * {
    public <init>(...);
}

# SnakeYAML Keep Rules
-keep class org.yaml.snakeyaml.** { *; }
-dontwarn org.yaml.snakeyaml.**