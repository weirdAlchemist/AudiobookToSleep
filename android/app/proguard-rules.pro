# Some plugins are called from Dart over JNI (the `jni` package), which finds
# Java/Kotlin classes, fields and methods by exact name at runtime. R8 renames
# or removes anything it thinks is unused, so without these rules release
# builds fail at startup (e.g. "Loading settings failed").

# shared_preferences_android 2.5.x ships no keep rules. Dart looks up its
# classes and methods by name (lib/src/messages.g.jni.dart).
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Kotlin types that appear in those signatures, or that the jni runtime itself
# looks up to call Kotlin suspend functions: Unit.INSTANCE,
# Result$Failure.exception, IntrinsicsKt.getCOROUTINE_SUSPENDED() (inherited
# from IntrinsicsKt's hidden parent classes), CoroutineSingletons.
-keep class kotlin.coroutines.** { *; }
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$* { *; }
-keepnames class kotlin.jvm.internal.DefaultConstructorMarker
