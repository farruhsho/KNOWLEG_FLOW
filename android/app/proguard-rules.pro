# Flutter / Firebase / Play Billing keep rules. Flutter's Gradle plugin adds the
# core Flutter rules; these cover reflection used by plugins.
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.android.billingclient.** { *; }
-keepattributes Signature, *Annotation*, InnerClasses, EnclosingMethod
-dontwarn com.google.android.play.core.**
