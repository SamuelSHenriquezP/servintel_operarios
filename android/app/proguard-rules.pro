# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Firebase Core
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firestore
-keep class com.google.firebase.firestore.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Firebase Auth
-keep class com.google.firebase.auth.** { *; }

# Firebase Common
-keep class com.google.firebase.components.** { *; }
-keep class com.google.firebase.provider.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

# Keep all model classes (data passed to/from Firestore)
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
    @com.google.firebase.firestore.PropertyName <methods>;
}

# url_launcher
-keep class androidx.browser.** { *; }

# Geolocator
-keep class com.baseflow.geolocator.** { *; }
