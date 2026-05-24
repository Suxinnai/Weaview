package com.weaview.weaview_flutter

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.MediaPlayer
import android.media.MediaScannerConnection
import android.media.AudioTrack
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.speech.tts.TextToSpeech
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val notificationPermissionRequestCode = 42019
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var mediaPlayer: MediaPlayer? = null
    private var ttsAudioFile: File? = null
    private var pcmAudioTrack: AudioTrack? = null
    private var pcmExecutor: ExecutorService? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "weaview/native_tts"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "speak" -> speakText(
                    call.argument<String>("text").orEmpty(),
                    call.argument<String>("locale") ?: "zh-CN",
                    result
                )
                "playAudio" -> playAudio(
                    call.argument<ByteArray>("bytes"),
                    call.argument<String>("mimeType") ?: "audio/mpeg",
                    result
                )
                "startPcm16Stream" -> startPcm16Stream(
                    call.argument<Int>("sampleRate") ?: 24000,
                    result
                )
                "appendPcm16" -> appendPcm16(
                    call.argument<ByteArray>("bytes"),
                    result
                )
                "finishPcm16Stream" -> finishPcm16Stream(result)
                "stop" -> {
                    tts?.stop()
                    stopAudioPlayback()
                    stopPcm16Stream()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "weaview/native_links"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openUrl" -> openUrl(call.argument<String>("url").orEmpty(), result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "weaview/native_media"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveImageToGallery" -> saveImageToGallery(
                    call.argument<String>("path").orEmpty(),
                    call.argument<String>("name").orEmpty(),
                    call.argument<String>("mimeType") ?: "image/png",
                    result
                )
                "generatedImageDirectory" -> generatedImageDirectory(result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "weaview/native_notifications"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "ensurePermission" -> ensureNotificationPermission(result)
                "show" -> showLocalNotification(
                    call.argument<String>("title").orEmpty(),
                    call.argument<String>("body").orEmpty(),
                    result
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun ensureNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            notificationPermissionRequestCode
        )
        result.success(false)
    }

    private fun speakText(text: String, locale: String, result: MethodChannel.Result) {
        if (text.isBlank()) {
            result.error("EMPTY_TEXT", "没有可朗读的内容", null)
            return
        }
        stopAudioPlayback()
        fun speakNow() {
            val engine = tts
            if (engine == null || !ttsReady) {
                result.error("TTS_NOT_READY", "系统语音引擎未就绪", null)
                return
            }
            val targetLocale = if (locale.lowercase().startsWith("zh")) {
                Locale.SIMPLIFIED_CHINESE
            } else {
                Locale.forLanguageTag(locale)
            }
            engine.language = targetLocale
            engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "weaview_tts")
            result.success(null)
        }

        val existing = tts
        if (existing != null && ttsReady) {
            speakNow()
            return
        }
        tts = TextToSpeech(this) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            if (ttsReady) {
                speakNow()
            } else {
                result.error("TTS_INIT_FAILED", "系统语音引擎初始化失败", null)
            }
        }
    }

    private fun playAudio(bytes: ByteArray?, mimeType: String, result: MethodChannel.Result) {
        if (bytes == null || bytes.isEmpty()) {
            result.error("EMPTY_AUDIO", "TTS 服务没有返回音频数据", null)
            return
        }
        try {
            tts?.stop()
            stopAudioPlayback()
            val extension = if (mimeType.lowercase().contains("wav")) ".wav" else ".mp3"
            val file = File.createTempFile("weaview_tts_", extension, cacheDir)
            file.writeBytes(bytes)
            val player = MediaPlayer()
            mediaPlayer = player
            ttsAudioFile = file
            var replied = false
            player.setOnPreparedListener {
                if (!replied) {
                    replied = true
                    result.success(null)
                }
                it.start()
            }
            player.setOnCompletionListener {
                stopAudioPlayback()
            }
            player.setOnErrorListener { _, what, extra ->
                val message = "音频播放失败，错误码：$what/$extra"
                stopAudioPlayback()
                if (!replied) {
                    replied = true
                    result.error("AUDIO_PLAYBACK_FAILED", message, null)
                }
                true
            }
            player.setDataSource(file.absolutePath)
            player.prepareAsync()
        } catch (error: Exception) {
            stopAudioPlayback()
            result.error("AUDIO_PLAYBACK_FAILED", error.message ?: "音频播放失败", null)
        }
    }

    private fun startPcm16Stream(sampleRate: Int, result: MethodChannel.Result) {
        try {
            tts?.stop()
            stopAudioPlayback()
            stopPcm16Stream()
            val minBuffer = AudioTrack.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            val bufferSize = maxOf(minBuffer, sampleRate)
            val track = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                AudioTrack.Builder()
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build()
                    )
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setSampleRate(sampleRate)
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                            .build()
                    )
                    .setBufferSizeInBytes(bufferSize)
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .build()
            } else {
                @Suppress("DEPRECATION")
                AudioTrack(
                    android.media.AudioManager.STREAM_MUSIC,
                    sampleRate,
                    AudioFormat.CHANNEL_OUT_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    bufferSize,
                    AudioTrack.MODE_STREAM
                )
            }
            pcmAudioTrack = track
            pcmExecutor = Executors.newSingleThreadExecutor()
            track.play()
            result.success(null)
        } catch (error: Exception) {
            stopPcm16Stream()
            result.error("PCM_STREAM_START_FAILED", error.message ?: "流式语音播放启动失败", null)
        }
    }

    private fun appendPcm16(bytes: ByteArray?, result: MethodChannel.Result) {
        val chunk = bytes
        val track = pcmAudioTrack
        val executor = pcmExecutor
        if (chunk == null || chunk.isEmpty()) {
            result.success(null)
            return
        }
        if (track == null || executor == null) {
            result.error("PCM_STREAM_NOT_READY", "流式语音播放器未启动", null)
            return
        }
        executor.execute {
            try {
                track.write(chunk, 0, chunk.size)
            } catch (_: Exception) {
            }
        }
        result.success(null)
    }

    private fun finishPcm16Stream(result: MethodChannel.Result) {
        val track = pcmAudioTrack
        val executor = pcmExecutor
        if (track == null || executor == null) {
            result.success(null)
            return
        }
        executor.execute {
            try {
                track.stop()
            } catch (_: Exception) {
            }
            try {
                track.release()
            } catch (_: Exception) {
            }
        }
        pcmAudioTrack = null
        pcmExecutor = null
        executor.shutdown()
        result.success(null)
    }

    private fun stopAudioPlayback() {
        try {
            mediaPlayer?.stop()
        } catch (_: Exception) {
        }
        try {
            mediaPlayer?.release()
        } catch (_: Exception) {
        }
        mediaPlayer = null
        try {
            ttsAudioFile?.delete()
        } catch (_: Exception) {
        }
        ttsAudioFile = null
    }

    private fun stopPcm16Stream() {
        val track = pcmAudioTrack
        val executor = pcmExecutor
        pcmAudioTrack = null
        pcmExecutor = null
        try {
            executor?.shutdownNow()
        } catch (_: Exception) {
        }
        try {
            track?.pause()
        } catch (_: Exception) {
        }
        try {
            track?.flush()
        } catch (_: Exception) {
        }
        try {
            track?.release()
        } catch (_: Exception) {
        }
    }

    private fun openUrl(url: String, result: MethodChannel.Result) {
        if (url.isBlank()) {
            result.error("EMPTY_URL", "链接为空", null)
            return
        }
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                addCategory(Intent.CATEGORY_BROWSABLE)
            }
            startActivity(intent)
            result.success(null)
        } catch (error: ActivityNotFoundException) {
            result.error("NO_BROWSER", "没有可打开链接的应用", null)
        } catch (error: Exception) {
            result.error("OPEN_URL_FAILED", error.message ?: "打开链接失败", null)
        }
    }

    private fun showLocalNotification(
        title: String,
        body: String,
        result: MethodChannel.Result
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            result.success(false)
            return
        }
        try {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channelId = "weaview_status"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    "织境提醒",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = "生图和消息状态提醒"
                }
                manager.createNotificationChannel(channel)
            }
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val pendingIntent = launchIntent?.let {
                PendingIntent.getActivity(
                    this,
                    0,
                    it,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            }
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, channelId)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
            }
            val notification = builder
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(title.ifBlank { "织境" })
                .setContentText(body)
                .setStyle(Notification.BigTextStyle().bigText(body))
                .setAutoCancel(true)
                .apply {
                    if (pendingIntent != null) setContentIntent(pendingIntent)
                }
                .build()
            manager.notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), notification)
            result.success(true)
        } catch (error: Exception) {
            result.error("NOTIFICATION_FAILED", error.message ?: "通知发送失败", null)
        }
    }

    private fun saveImageToGallery(
        path: String,
        name: String,
        mimeType: String,
        result: MethodChannel.Result
    ) {
        val source = File(path)
        if (!source.exists() || !source.isFile) {
            result.error("IMAGE_NOT_FOUND", "图片文件不存在", null)
            return
        }
        val displayName = galleryDisplayName(name, mimeType)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
                    put(MediaStore.Images.Media.MIME_TYPE, mimeType)
                    put(
                        MediaStore.Images.Media.RELATIVE_PATH,
                        "${Environment.DIRECTORY_PICTURES}/Weaview"
                    )
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
                val uri = contentResolver.insert(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    values
                ) ?: throw IllegalStateException("无法创建相册文件")
                try {
                    source.inputStream().use { input ->
                        contentResolver.openOutputStream(uri)?.use { output ->
                            input.copyTo(output)
                        } ?: throw IllegalStateException("无法写入相册文件")
                    }
                    values.clear()
                    values.put(MediaStore.Images.Media.IS_PENDING, 0)
                    contentResolver.update(uri, values, null, null)
                    result.success("Pictures/Weaview/$displayName")
                } catch (error: Exception) {
                    contentResolver.delete(uri, null, null)
                    throw error
                }
            } else {
                @Suppress("DEPRECATION")
                val directory = File(
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
                    "Weaview"
                )
                if (!directory.exists() && !directory.mkdirs()) {
                    throw IllegalStateException("无法创建相册目录")
                }
                val target = uniqueGalleryFile(directory, displayName)
                source.copyTo(target, overwrite = false)
                MediaScannerConnection.scanFile(
                    this,
                    arrayOf(target.absolutePath),
                    arrayOf(mimeType),
                    null
                )
                result.success(target.absolutePath)
            }
        } catch (error: Exception) {
            result.error("SAVE_IMAGE_FAILED", error.message ?: "保存图片失败", null)
        }
    }

    private fun generatedImageDirectory(result: MethodChannel.Result) {
        try {
            val directory = File(filesDir, "weaview_generated_images")
            if (!directory.exists() && !directory.mkdirs()) {
                throw IllegalStateException("无法创建图片缓存目录")
            }
            result.success(directory.absolutePath)
        } catch (error: Exception) {
            result.error("MEDIA_DIR_FAILED", error.message ?: "图片缓存目录不可用", null)
        }
    }

    private fun galleryDisplayName(name: String, mimeType: String): String {
        val fallback = "weaview_image_${System.currentTimeMillis()}"
        val cleaned = name
            .ifBlank { fallback }
            .replace(Regex("[\\\\/:*?\"<>|]"), "_")
            .take(80)
            .ifBlank { fallback }
        val lower = cleaned.lowercase()
        if (lower.endsWith(".png") || lower.endsWith(".jpg") ||
            lower.endsWith(".jpeg") || lower.endsWith(".webp")
        ) {
            return cleaned
        }
        val extension = when {
            mimeType.lowercase().contains("jpeg") || mimeType.lowercase().contains("jpg") -> "jpg"
            mimeType.lowercase().contains("webp") -> "webp"
            else -> "png"
        }
        return "$cleaned.$extension"
    }

    private fun uniqueGalleryFile(directory: File, displayName: String): File {
        val dot = displayName.lastIndexOf('.')
        val base = if (dot > 0) displayName.substring(0, dot) else displayName
        val extension = if (dot > 0) displayName.substring(dot) else ""
        var candidate = File(directory, displayName)
        var index = 1
        while (candidate.exists()) {
            candidate = File(directory, "$base-$index$extension")
            index += 1
        }
        return candidate
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        tts = null
        stopAudioPlayback()
        stopPcm16Stream()
        super.onDestroy()
    }
}
