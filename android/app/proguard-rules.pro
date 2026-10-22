# shared_preferences_android 2.5.x is called from Dart over JNI, which finds
# Java methods by exact name and signature at runtime. The plugin ships no
# keep rules, so R8 renames things in release builds and startup fails with
# NoSuchMethodError on SharedPreferencesApiRegistrar.getAll.
#
# Keep the plugin's classes, and the original names of the Kotlin types that
# appear in the signatures Dart looks up (see lib/src/messages.g.jni.dart).
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keepnames class kotlin.coroutines.Continuation
-keepnames class kotlin.jvm.internal.DefaultConstructorMarker
