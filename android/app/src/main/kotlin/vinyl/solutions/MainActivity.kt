package vinyl.solutions

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vinyl/analyze")
            .setMethodCallHandler { call, result ->
                if (call.method == "analyze") {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("args", "sin ruta", null)
                    } else {
                        thread {
                            try {
                                val r = TrackAnalyzer.analyze(path)
                                runOnUiThread { result.success(r) }
                            } catch (e: Throwable) {
                                runOnUiThread { result.error("fail", e.message, null) }
                            }
                        }
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
