# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# device_info_plus
-keep class dev.fluttercommunity.plus.device_info.** { *; }

# shared_preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# url_launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# vibration
-keep class com.benjaminabel.vibration.** { *; }

# http / networking
-dontwarn javax.annotation.**
-keepattributes *Annotation*
-dontwarn com.google.android.play.**
-keep class com.google.android.play.** { *; }