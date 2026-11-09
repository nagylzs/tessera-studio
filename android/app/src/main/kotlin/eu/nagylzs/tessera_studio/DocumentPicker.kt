package eu.nagylzs.tessera_studio

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.InputStream
import java.util.concurrent.ExecutorService

/// The open dialog on Android, in place of file_picker's. Both show the
/// system's document picker, but file_picker asks for CATEGORY_OPENABLE,
/// which greys out every document without a file behind it: a Google
/// Sheet in Drive is such a "virtual document". Without the category it
/// can be picked, and is read as the spreadsheet its provider converts it
/// to (found on the owner's pad, 2026-11-09).
///
/// Methods on `eu.nagylzs.tessera_studio/pick`:
/// - `pick` → null when cancelled, else {name, uri, type}, where `type`
///   is the media type a virtual document is read as (null for a file)
///   and `name` then ends in its extension; {name, unsupported: true} for
///   a virtual document with no spreadsheet form (a Google Doc);
/// - `head` {uri, type, length} → the first `length` bytes;
/// - `copy` {uri, type, name} → the path of a copy in [cacheDir].
/// Reading may wait on the network (Drive), so it runs on [executor].
class DocumentPicker(
    private val activity: Activity,
    private val executor: ExecutorService,
    private val cacheDir: () -> File,
) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "eu.nagylzs.tessera_studio/pick"
        private const val REQUEST = 0x7e55

        /// What a virtual document may be read as, best first, and the
        /// extension its name gets: XLSX keeps every sheet.
        private val conversions = listOf(
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" to "xlsx",
            "application/vnd.oasis.opendocument.spreadsheet" to "ods",
            "text/csv" to "csv",
            "text/tab-separated-values" to "tsv",
        )
    }

    private var pending: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pick" -> pick(result)
            "head" -> background(result) {
                val length = call.argument<Int>("length")!!
                open(call).use { input ->
                    val buffer = ByteArray(length)
                    var n = 0
                    while (n < length) {
                        val read = input.read(buffer, n, length - n)
                        if (read < 0) break
                        n += read
                    }
                    buffer.copyOf(n)
                }
            }
            "copy" -> background(result) {
                val name = safeFileName(call.argument<String>("name")!!)
                val target = File(cacheDir(), "${System.nanoTime()}_$name")
                open(call).use { input -> target.outputStream().use { input.copyTo(it) } }
                target.path
            }
            else -> result.notImplemented()
        }
    }

    private fun pick(result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", "the picker is already open", null)
            return
        }
        // No CATEGORY_OPENABLE: it hides the virtual documents.
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).setType("*/*")
        try {
            activity.startActivityForResult(intent, REQUEST)
            pending = result
        } catch (e: ActivityNotFoundException) {
            result.error("unavailable", e.message, null)
        }
    }

    /// The activity's result, if it is the picker's; false otherwise.
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val result = pending ?: return true
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
        } else {
            background(result) { describe(uri) }
        }
        return true
    }

    private fun describe(uri: Uri): Map<String, Any?> {
        var name: String? = null
        var flags = 0
        activity.contentResolver.query(uri, null, null, null, null)?.use { c ->
            if (c.moveToFirst()) {
                val n = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (n >= 0 && !c.isNull(n)) name = c.getString(n)
                val f = c.getColumnIndex(DocumentsContract.Document.COLUMN_FLAGS)
                if (f >= 0 && !c.isNull(f)) flags = c.getInt(f)
            }
        }
        val base = safeFileName(name?.takeIf { it.isNotBlank() } ?: uri.lastPathSegment ?: "file")
        if (flags and DocumentsContract.Document.FLAG_VIRTUAL_DOCUMENT == 0) {
            return mapOf("name" to base, "uri" to uri.toString(), "type" to null)
        }
        val offered = activity.contentResolver.getStreamTypes(uri, "*/*")?.toSet().orEmpty()
        val (type, extension) = conversions.firstOrNull { it.first in offered }
            ?: return mapOf("name" to base, "unsupported" to true)
        val named = if (base.endsWith(".$extension", ignoreCase = true)) base else "$base.$extension"
        return mapOf("name" to named, "uri" to uri.toString(), "type" to type)
    }

    private fun open(call: MethodCall): InputStream {
        val uri = Uri.parse(call.argument<String>("uri")!!)
        val type = call.argument<String>("type")
        val resolver = activity.contentResolver
        val stream = if (type == null) {
            resolver.openInputStream(uri)
        } else {
            resolver.openTypedAssetFileDescriptor(uri, type, null)?.createInputStream()
        }
        return stream ?: throw IllegalStateException("no stream for $uri")
    }

    /// Runs [work] on the executor and answers [result] on the main thread.
    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        executor.execute {
            try {
                val answer = work()
                activity.runOnUiThread { result.success(answer) }
            } catch (e: Exception) {
                activity.runOnUiThread { result.error("read", e.message ?: e.toString(), null) }
            }
        }
    }
}

/// [name] without path separators, for a file in the cache.
fun safeFileName(name: String) = name.replace('/', '_').replace('\\', '_')
