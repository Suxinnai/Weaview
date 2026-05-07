import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let speechSynthesizer = AVSpeechSynthesizer()
  private var audioPlayer: AVAudioPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let didLaunch = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    configureTtsChannel()
    return didLaunch
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func configureTtsChannel() {
    if let controller = window?.rootViewController as? FlutterViewController {
      FlutterMethodChannel(
        name: "weaview/native_tts",
        binaryMessenger: controller.binaryMessenger
      ).setMethodCallHandler { [weak self] call, result in
        self?.handleTtsCall(call, result: result)
      }
    }
  }

  private func handleTtsCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "speak":
      guard
        let args = call.arguments as? [String: Any],
        let text = args["text"] as? String,
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        result(FlutterError(code: "EMPTY_TEXT", message: "没有可朗读的内容", details: nil))
        return
      }
      let locale = (call.arguments as? [String: Any])?["locale"] as? String ?? "zh-CN"
      audioPlayer?.stop()
      speechSynthesizer.stopSpeaking(at: .immediate)
      let utterance = AVSpeechUtterance(string: text)
      utterance.voice = AVSpeechSynthesisVoice(language: locale)
      speechSynthesizer.speak(utterance)
      result(nil)
    case "playAudio":
      guard
        let args = call.arguments as? [String: Any],
        let data = args["bytes"] as? FlutterStandardTypedData,
        !data.data.isEmpty
      else {
        result(FlutterError(code: "EMPTY_AUDIO", message: "TTS 服务没有返回音频数据", details: nil))
        return
      }
      do {
        speechSynthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        audioPlayer = try AVAudioPlayer(data: data.data)
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
        result(nil)
      } catch {
        result(FlutterError(code: "AUDIO_PLAYBACK_FAILED", message: error.localizedDescription, details: nil))
      }
    case "stop":
      speechSynthesizer.stopSpeaking(at: .immediate)
      audioPlayer?.stop()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
