package com.weirdalchemist.audiobook_to_sleep

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// Lists and controls other apps' media sessions (Spotify, Audible, ...) for
// the Dart side (lib/audio/external_media.dart).
class MediaBridge(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "audiobook_to_sleep/media"
        private val REWIND_HINTS = listOf("rewind", "replay", "back", "previous")
    }

    private val listener = ComponentName(context, MediaListenerService::class.java)
    private val sessionManager =
        context.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "hasAccess" -> result.success(hasAccess())
                "openAccessSettings" -> {
                    openAccessSettings()
                    result.success(null)
                }
                "sessions" -> result.success(controllers().map(::describe))
                "control" -> {
                    val pkg = call.argument<String>("package")
                    val controller = controllers().firstOrNull { it.packageName == pkg }
                    if (controller == null) {
                        result.error("no_session", "No media session for $pkg", null)
                    } else {
                        control(controller, call.argument<String>("action") ?: "", call.argument<Number>("positionMs"))
                        result.success(null)
                    }
                }
                "getVolume" -> result.success(
                    mapOf(
                        "volume" to audioManager.getStreamVolume(AudioManager.STREAM_MUSIC),
                        "max" to audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC),
                    )
                )
                "setVolume" -> {
                    val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val volume = (call.argument<Number>("volume")?.toInt() ?: 0).coerceIn(0, max)
                    // Flags 0: no volume panel popping up in the dark.
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, volume, 0)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: SecurityException) {
            result.error("no_access", "Notification access is not granted", null)
        }
    }

    private fun hasAccess(): Boolean {
        val enabled = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
            ?: return false
        return enabled.split(":").any { ComponentName.unflattenFromString(it) == listener }
    }

    private fun openAccessSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Straight to this app's toggle.
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                .putExtra(Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME, listener.flattenToString())
        } else {
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            context.startActivity(
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }

    // Most recently active first; our own session (the built-in player) excluded.
    private fun controllers(): List<MediaController> =
        sessionManager.getActiveSessions(listener).filter { it.packageName != context.packageName }

    private fun describe(c: MediaController): Map<String, Any?> {
        val meta = c.metadata
        val state = c.playbackState
        return mapOf(
            "package" to c.packageName,
            "appName" to appName(c.packageName),
            "title" to (meta?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: ""),
            "subtitle" to (meta?.getString(MediaMetadata.METADATA_KEY_ARTIST)
                ?: meta?.getString(MediaMetadata.METADATA_KEY_ALBUM) ?: ""),
            "durationMs" to (meta?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L),
            "positionMs" to currentPosition(state),
            "playing" to (state?.state == PlaybackState.STATE_PLAYING),
            "canSeek" to ((state?.actions ?: 0L) and PlaybackState.ACTION_SEEK_TO != 0L),
        )
    }

    // The reported position is a snapshot; extrapolate while playing.
    private fun currentPosition(state: PlaybackState?): Long {
        if (state == null) return 0L
        if (state.state != PlaybackState.STATE_PLAYING || state.lastPositionUpdateTime <= 0L) {
            return state.position
        }
        val elapsed = SystemClock.elapsedRealtime() - state.lastPositionUpdateTime
        return state.position + (elapsed * state.playbackSpeed).toLong()
    }

    private fun control(c: MediaController, action: String, positionMs: Number?) {
        val controls = c.transportControls
        when (action) {
            "play" -> controls.play()
            "pause" -> controls.pause()
            "seekTo" -> controls.seekTo(positionMs?.toLong() ?: 0L)
            "fastForward" -> controls.fastForward()
            "rewind" -> rewind(c)
        }
    }

    // Some audiobook apps don't support the standard rewind action and offer a
    // custom "back 30 s" button instead.
    private fun rewind(c: MediaController) {
        val state = c.playbackState
        if (state == null || (state.actions and PlaybackState.ACTION_REWIND) != 0L) {
            c.transportControls.rewind()
            return
        }
        val custom = state.customActions.firstOrNull { a ->
            val text = "${a.action} ${a.name}".lowercase()
            REWIND_HINTS.any { text.contains(it) }
        }
        if (custom != null) {
            c.transportControls.sendCustomAction(custom, null)
        } else {
            c.transportControls.rewind()
        }
    }

    private fun appName(pkg: String): String = try {
        val pm = context.packageManager
        pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
    } catch (e: Exception) {
        pkg
    }
}
