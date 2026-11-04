package app.main

import android.Manifest
import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.ComponentActivity
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import kotlinx.coroutines.launch

/** Push with Firebase Cloud Messaging, started from the options in alpha_config.json (no Gradle plugin). */
object Push {
    private const val CHANNEL = "alpha"

    fun ensureFirebase(context: android.content.Context, config: AlphaConfig): Boolean {
        if (FirebaseApp.getApps(context).isNotEmpty()) return true
        val f = config.backend.optJSONObject("firebase") ?: return false
        val apiKey = f.optString("apiKey")
        val appId = f.optString("appId")
        if (apiKey.isEmpty() || appId.isEmpty()) return false
        FirebaseApp.initializeApp(
            context,
            FirebaseOptions.Builder().setApiKey(apiKey).setApplicationId(appId)
                .setGcmSenderId(f.optString("senderId")).setProjectId(f.optString("projectId")).build(),
        )
        return true
    }

    fun setup(activity: ComponentActivity, backend: Backend) {
        if (!backend.config.push || !ensureFirebase(activity, backend.config)) return
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7)
        }
        FirebaseMessaging.getInstance().token.addOnSuccessListener { token ->
            activity.lifecycleScope.launch { runCatching { backend.registerDevice(token) } }
        }
    }

    @SuppressLint("MissingPermission")
    fun show(context: android.content.Context, title: String, body: String) {
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CHANNEL, "الإشعارات", NotificationManager.IMPORTANCE_HIGH))
        val open = PendingIntent.getActivity(
            context, 0, Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val n = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title).setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true).setContentIntent(open)
            .setPriority(NotificationCompat.PRIORITY_HIGH).build()
        if (Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            nm.notify(System.currentTimeMillis().toInt(), n)
        }
    }
}

/** Messages that arrive while the app is open (Android shows the others by itself). New tokens are saved. */
class PushService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        val n = message.notification ?: return
        Push.show(this, n.title ?: "", n.body ?: "")
    }

    override fun onNewToken(token: String) {
        getSharedPreferences("alpha", MODE_PRIVATE).edit().putString("push_token", token).apply()
    }
}
