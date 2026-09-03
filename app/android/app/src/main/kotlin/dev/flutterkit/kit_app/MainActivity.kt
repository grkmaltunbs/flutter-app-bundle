package dev.flutterkit.kit_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createChannels()
    }

    // The channels the Mac's pushes name (app/lib/src/host/push_sender.dart):
    // asks — allow, a question, a sign-in — problems, and turns that ended,
    // so any one can be silenced in the phone's settings without the others.
    // High importance: heads-up and sound, the way a person waiting on the
    // other end deserves. FCM falls back to "Miscellaneous" for a channel
    // that does not exist, which is why they are made here, before any
    // message arrives.
    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel("asks", "Claude needs you", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "A command to allow, a question to answer, a website to sign in to"
            }
        )
        nm.createNotificationChannel(
            NotificationChannel("problems", "Problems", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "The session stopped or a turn ended in an error"
            }
        )
        // Default importance: a sound and the shade, no heads-up — the reply
        // waits in the app.
        nm.createNotificationChannel(
            NotificationChannel("done", "Turn ended", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Claude finished what you sent, while you were away"
            }
        )
    }
}
