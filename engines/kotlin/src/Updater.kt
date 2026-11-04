package app.main

import android.content.Context
import android.content.Intent
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.io.File
import java.util.concurrent.TimeUnit

data class UpdateInfo(val version: Long, val name: String, val apk: String, val notes: String)

/** In-app updates: the build publishes each version at a public link (no GitHub account needed). */
object Updater {
    private val http = OkHttpClient.Builder().callTimeout(10, TimeUnit.MINUTES).build()

    suspend fun check(config: AlphaConfig): UpdateInfo? = withContext(Dispatchers.IO) {
        val u = config.json.optJSONObject("update") ?: return@withContext null
        val url = u.optString("url")
        val current = u.optLong("version")
        if (url.isEmpty() || current == 0L) return@withContext null
        runCatching {
            http.newCall(Request.Builder().url("$url?t=${System.currentTimeMillis()}").build()).execute().use { res ->
                if (!res.isSuccessful) return@use null
                val j = JSONObject(res.body?.string() ?: "{}")
                val v = j.optLong("version")
                if (v <= current || j.optString("apk").isEmpty()) null
                else UpdateInfo(v, j.optString("name", "1.0.$v"), j.optString("apk"), j.optString("notes"))
            }
        }.getOrNull()
    }

    suspend fun download(context: Context, info: UpdateInfo, progress: (Float) -> Unit): File = withContext(Dispatchers.IO) {
        val file = File(context.cacheDir, "update-${info.version}.apk")
        http.newCall(Request.Builder().url(info.apk).build()).execute().use { res ->
            if (!res.isSuccessful) throw BackendException("تعذّر تحميل التحديث (${res.code})")
            val body = res.body ?: throw BackendException("تعذّر تحميل التحديث")
            val total = body.contentLength()
            body.byteStream().use { input ->
                file.outputStream().use { out ->
                    val buf = ByteArray(64 * 1024)
                    var got = 0L
                    while (true) {
                        val n = input.read(buf)
                        if (n < 0) break
                        out.write(buf, 0, n)
                        got += n
                        if (total > 0) progress(got.toFloat() / total)
                    }
                }
            }
        }
        file
    }

    fun install(context: Context, file: File) {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.alpha.files", file)
        context.startActivity(
            Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }
}

@Composable
fun UpdateDialog(config: AlphaConfig) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var info by remember { mutableStateOf<UpdateInfo?>(null) }
    var downloading by remember { mutableStateOf(false) }
    var progress by remember { mutableFloatStateOf(0f) }
    var error by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) { info = Updater.check(config) }
    val u = info ?: return
    AlertDialog(
        onDismissRequest = { if (!downloading) info = null },
        title = { Text(if (downloading) "يحمّل التحديث…" else "تحديث جديد") },
        text = {
            Column {
                Text("النسخة ${u.name} جاهزة." + if (u.notes.isNotEmpty()) "\n\n${u.notes}" else "")
                if (downloading) {
                    Spacer(Modifier.height(12.dp))
                    LinearProgressIndicator(progress = { progress })
                }
                error?.let { Text(it) }
            }
        },
        confirmButton = {
            Button(enabled = !downloading, onClick = {
                downloading = true
                scope.launch {
                    try {
                        val file = Updater.download(context, u) { progress = it }
                        Updater.install(context, file)
                        info = null
                    } catch (e: Exception) {
                        error = e.message
                    } finally {
                        downloading = false
                    }
                }
            }) { Text("حدّث الآن") }
        },
        dismissButton = { if (!downloading) TextButton(onClick = { info = null }) { Text("لاحقاً") } },
    )
}
