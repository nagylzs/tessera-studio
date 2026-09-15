package eu.nagylzs.tessera_studio

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.util.concurrent.Executors

/// Delivers files the system hands us ("Open with…" = ACTION_VIEW, the
/// share sheet = ACTION_SEND) to Dart. A content Uri can only be read
/// while the intent's temporary grant lasts, so the stream is copied to
/// the cache directory right away and Dart gets a plain path plus the
/// original display name (the cache name carries no usable extension).
///
/// Events on `eu.nagylzs.tessera_studio/open` are maps with an `event`:
/// `started` {name}, `ready` {name, path}, `failed` {name, error}. Events
/// raised before Dart listens are queued and flushed on subscription.
class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "eu.nagylzs.tessera_studio/open"
    }

    private var sink: EventChannel.EventSink? = null
    private val queued = ArrayList<Map<String, Any?>>()
    private val executor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    sink = events
                    for (e in queued) events.success(e)
                    queued.clear()
                }

                override fun onCancel(arguments: Any?) {
                    sink = null
                }
            })
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        clearOpenCache()
        if (savedInstanceState == null) handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    override fun onDestroy() {
        executor.shutdownNow()
        super.onDestroy()
    }

    private fun handleIntent(intent: Intent?) {
        val uri: Uri = when (intent?.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND ->
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
            else -> null
        } ?: return
        val name = displayName(uri, intent?.type)
        emit(mapOf("event" to "started", "name" to name))
        executor.execute {
            try {
                val target = File(openCacheDir(), "${System.nanoTime()}_$name")
                contentResolver.openInputStream(uri).use { input ->
                    if (input == null) throw IllegalStateException("no stream for $uri")
                    target.outputStream().use { input.copyTo(it) }
                }
                post(mapOf("event" to "ready", "name" to name, "path" to target.path))
            } catch (e: Exception) {
                post(mapOf("event" to "failed", "name" to name, "error" to (e.message ?: e.toString())))
            }
        }
    }

    /// The name the sender shows for [uri]: the DISPLAY_NAME column for a
    /// content Uri, else the last path segment, else a name made from the
    /// MIME type so the extension still says what the file is.
    private fun displayName(uri: Uri, mimeType: String?): String {
        if (uri.scheme == "content") {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { c ->
                    if (c.moveToFirst() && !c.isNull(0)) {
                        val n = c.getString(0)
                        if (n.isNotBlank()) return sanitize(n)
                    }
                }
        }
        uri.lastPathSegment?.let { if (it.isNotBlank() && it.contains('.')) return sanitize(it) }
        val ext = mimeType?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }
        return if (ext == null) "file" else "file.$ext"
    }

    private fun sanitize(name: String) = name.replace('/', '_').replace('\\', '_')

    private fun openCacheDir() = File(cacheDir, "open").apply { mkdirs() }

    private fun clearOpenCache() {
        File(cacheDir, "open").listFiles()?.forEach { it.delete() }
    }

    private fun post(event: Map<String, Any?>) = runOnUiThread { emit(event) }

    private fun emit(event: Map<String, Any?>) {
        val s = sink
        if (s == null) queued.add(event) else s.success(event)
    }
}
