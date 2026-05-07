package com.weaview.weaview_flutter

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val speechRequestCode = 42017
    private val speechPermissionRequestCode = 42018
    private var pendingSpeechResult: MethodChannel.Result? = null
    private var pendingSpeechLocale: String = "zh-CN"
    private var speechRecognizer: SpeechRecognizer? = null
    private var lastPartialSpeech = ""
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var mediaPlayer: MediaPlayer? = null
    private var ttsAudioFile: File? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "weaview/native_speech"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "listen" -> startNativeSpeech(call.argument<String>("locale") ?: "zh-CN", result)
                "cancel" -> {
                    cancelNativeSpeech()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
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
                "stop" -> {
                    tts?.stop()
                    stopAudioPlayback()
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
    }

    private fun startNativeSpeech(locale: String, result: MethodChannel.Result) {
        if (pendingSpeechResult != null) {
            result.error("BUSY", "语音识别正在进行中", null)
            return
        }
        pendingSpeechResult = result
        pendingSpeechLocale = locale
        lastPartialSpeech = ""

        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(Manifest.permission.RECORD_AUDIO),
                speechPermissionRequestCode
            )
            return
        }

        startInlineSpeech(locale)
    }

    private fun startInlineSpeech(locale: String) {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            startSpeechIntent(locale)
            return
        }
        destroySpeechRecognizer()
        try {
            val recognizer = SpeechRecognizer.createSpeechRecognizer(this)
            speechRecognizer = recognizer
            recognizer.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) = Unit
                override fun onBeginningOfSpeech() = Unit
                override fun onRmsChanged(rmsdB: Float) = Unit
                override fun onBufferReceived(buffer: ByteArray?) = Unit
                override fun onEndOfSpeech() = Unit
                override fun onEvent(eventType: Int, params: Bundle?) = Unit

                override fun onPartialResults(partialResults: Bundle?) {
                    val partial = speechTextFromBundle(partialResults).trim()
                    if (partial.isNotEmpty()) lastPartialSpeech = partial
                }

                override fun onResults(results: Bundle?) {
                    val text = speechTextFromBundle(results).ifBlank { lastPartialSpeech }
                    finishSpeechSuccess(text)
                }

                override fun onError(error: Int) {
                    if (lastPartialSpeech.isNotBlank()) {
                        finishSpeechSuccess(lastPartialSpeech)
                        return
                    }
                    finishSpeechError("RECOGNITION_ERROR", speechErrorMessage(error))
                }
            })
            recognizer.startListening(speechIntent(locale, partialResults = true))
        } catch (error: Exception) {
            destroySpeechRecognizer()
            startSpeechIntent(locale)
        }
    }

    private fun startSpeechIntent(locale: String) {
        try {
            startActivityForResult(
                speechIntent(locale, partialResults = false).apply {
                    putExtra(RecognizerIntent.EXTRA_PROMPT, "请开始说话")
                },
                speechRequestCode
            )
        } catch (error: ActivityNotFoundException) {
            finishSpeechError("NO_RECOGNIZER", "系统没有可用的语音识别服务")
        } catch (error: Exception) {
            finishSpeechError("RECOGNIZER_START_FAILED", error.message ?: "语音识别启动失败")
        }
    }

    private fun speechIntent(locale: String, partialResults: Boolean): Intent {
        return Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, locale)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, partialResults)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
        }
    }

    private fun speechTextFromBundle(bundle: Bundle?): String {
        val matches = bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        return matches?.firstOrNull().orEmpty()
    }

    private fun finishSpeechSuccess(text: String) {
        val result = pendingSpeechResult ?: return
        pendingSpeechResult = null
        val cleaned = text.trim()
        destroySpeechRecognizer()
        if (cleaned.isEmpty()) {
            result.error("NO_MATCH", "没有识别到语音内容", null)
        } else {
            result.success(cleaned)
        }
    }

    private fun finishSpeechError(code: String, message: String) {
        val result = pendingSpeechResult ?: return
        pendingSpeechResult = null
        destroySpeechRecognizer()
        result.error(code, message, null)
    }

    private fun cancelNativeSpeech() {
        val result = pendingSpeechResult
        pendingSpeechResult = null
        try {
            speechRecognizer?.cancel()
        } catch (_: Exception) {
        }
        destroySpeechRecognizer()
        result?.error("CANCELLED", "语音识别已取消", null)
    }

    private fun destroySpeechRecognizer() {
        try {
            speechRecognizer?.destroy()
        } catch (_: Exception) {
        }
        speechRecognizer = null
    }

    private fun speechErrorMessage(error: Int): String {
        return when (error) {
            SpeechRecognizer.ERROR_AUDIO -> "录音失败，请检查麦克风权限或系统录音状态"
            SpeechRecognizer.ERROR_CLIENT -> "语音识别客户端异常"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "缺少麦克风权限"
            SpeechRecognizer.ERROR_NETWORK -> "语音识别网络连接失败"
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "语音识别网络超时"
            SpeechRecognizer.ERROR_NO_MATCH -> "没有识别到语音内容"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "语音识别服务正忙，请稍后再试"
            SpeechRecognizer.ERROR_SERVER -> "语音识别服务异常"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "没有检测到说话声音"
            else -> "语音识别失败，错误码：$error"
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != speechPermissionRequestCode) return
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (granted) {
            startInlineSpeech(pendingSpeechLocale)
        } else {
            finishSpeechError("PERMISSION_DENIED", "需要麦克风权限才能使用语音输入")
        }
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

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != speechRequestCode) return
        if (pendingSpeechResult == null) return
        if (resultCode != Activity.RESULT_OK) {
            finishSpeechError("CANCELLED", "语音识别已取消或未识别到内容")
            return
        }
        val matches = data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
        val text = matches?.firstOrNull().orEmpty()
        finishSpeechSuccess(text)
    }

    override fun onDestroy() {
        destroySpeechRecognizer()
        tts?.stop()
        tts?.shutdown()
        tts = null
        stopAudioPlayback()
        super.onDestroy()
    }
}
