package com.weaview.weaview_flutter

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.speech.RecognizerIntent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val speechRequestCode = 42017
    private var pendingSpeechResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "weaview/native_speech"
        ).setMethodCallHandler { call, result ->
            if (call.method != "listen") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pendingSpeechResult != null) {
                result.error("BUSY", "语音识别正在进行中", null)
                return@setMethodCallHandler
            }
            pendingSpeechResult = result
            val locale = call.argument<String>("locale") ?: "zh-CN"
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(
                    RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                    RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
                )
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
                putExtra(RecognizerIntent.EXTRA_PROMPT, "请开始说话")
            }
            try {
                startActivityForResult(intent, speechRequestCode)
            } catch (error: ActivityNotFoundException) {
                pendingSpeechResult = null
                result.error("NO_RECOGNIZER", "系统没有可用的语音识别服务", null)
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != speechRequestCode) return
        val result = pendingSpeechResult ?: return
        pendingSpeechResult = null
        if (resultCode != Activity.RESULT_OK) {
            result.error("CANCELLED", "语音识别已取消或未识别到内容", null)
            return
        }
        val matches = data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
        val text = matches?.firstOrNull().orEmpty()
        result.success(text)
    }
}
