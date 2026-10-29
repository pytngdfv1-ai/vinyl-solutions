package vinyl.solutions

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.sqrt

/**
 * Analiza el inicio de un tema (hasta ~75 s): primer instante con sonido y tempo (BPM).
 * Decodifica con MediaCodec y trabaja con la envolvente de energía (100 cuadros por segundo).
 */
object TrackAnalyzer {
    private const val MAX_FRAMES = 7500

    fun analyze(path: String): Map<String, Any> {
        val ex = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            ex.setDataSource(path)
            var idx = -1
            var fmt: MediaFormat? = null
            for (i in 0 until ex.trackCount) {
                val f = ex.getTrackFormat(i)
                val m = f.getString(MediaFormat.KEY_MIME) ?: ""
                if (m.startsWith("audio/")) {
                    idx = i
                    fmt = f
                    break
                }
            }
            if (idx < 0 || fmt == null) throw Exception("sin audio")
            ex.selectTrack(idx)
            val mime = fmt.getString(MediaFormat.KEY_MIME)!!
            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(fmt, null, null, 0)
            codec.start()

            var sr = fmt.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var ch = fmt.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            var hop = max(1, sr / 100)

            val env = ArrayList<Float>(MAX_FRAMES)
            var sumSq = 0.0
            var count = 0
            var chPos = 0
            var acc = 0f

            val info = MediaCodec.BufferInfo()
            var inDone = false
            var outDone = false
            var guard = 0
            while (!outDone && env.size < MAX_FRAMES && guard < 200000) {
                guard++
                if (!inDone) {
                    val i = codec.dequeueInputBuffer(10000)
                    if (i >= 0) {
                        val buf = codec.getInputBuffer(i)!!
                        val n = ex.readSampleData(buf, 0)
                        if (n < 0) {
                            codec.queueInputBuffer(i, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inDone = true
                        } else {
                            codec.queueInputBuffer(i, 0, n, ex.sampleTime, 0)
                            ex.advance()
                        }
                    }
                }
                val o = codec.dequeueOutputBuffer(info, 10000)
                if (o >= 0) {
                    val ob = codec.getOutputBuffer(o)!!
                    ob.position(info.offset)
                    ob.limit(info.offset + info.size)
                    val sb = ob.order(ByteOrder.nativeOrder()).asShortBuffer()
                    while (sb.hasRemaining()) {
                        acc += sb.get() / 32768f
                        chPos++
                        if (chPos >= ch) {
                            val m = acc / ch
                            sumSq += (m * m).toDouble()
                            count++
                            chPos = 0
                            acc = 0f
                            if (count >= hop) {
                                env.add(sqrt(sumSq / count).toFloat())
                                sumSq = 0.0
                                count = 0
                            }
                        }
                    }
                    codec.releaseOutputBuffer(o, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outDone = true
                } else if (o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val f = codec.outputFormat
                    sr = f.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    ch = max(1, f.getInteger(MediaFormat.KEY_CHANNEL_COUNT))
                    hop = max(1, sr / 100)
                }
            }

            if (env.size < 300) throw Exception("muy corto")
            val e = env.toFloatArray()

            // Primer instante con sonido sostenido.
            var peak = 0f
            for (v in e) if (v > peak) peak = v
            val thr = max(0.003f, peak * 0.05f)
            var start = 0
            var streak = 0
            for (i in e.indices) {
                if (e[i] > thr) {
                    streak++
                    if (streak >= 5) {
                        start = i - 4
                        break
                    }
                } else {
                    streak = 0
                }
            }
            val startMs = max(0, start) * 10

            val bpm = tempo(e, start)
            val out = HashMap<String, Any>()
            out["startMs"] = startMs
            out["bpm"] = bpm
            return out
        } finally {
            try {
                codec?.stop()
            } catch (_: Throwable) {
            }
            try {
                codec?.release()
            } catch (_: Throwable) {
            }
            ex.release()
        }
    }

    /** Tempo por autocorrelación de los inicios de nota; 0.0 si no se pudo. */
    private fun tempo(env: FloatArray, from: Int): Double {
        val n = env.size - from
        if (n < 800) return 0.0
        val v = FloatArray(n) { ln(1f + 50f * env[from + it]) }
        val o = FloatArray(n)
        var mean = 0f
        for (i in 1 until n) {
            o[i] = max(0f, v[i] - v[i - 1])
            mean += o[i]
        }
        mean /= n
        for (i in 0 until n) o[i] = max(0f, o[i] - mean)

        fun score(lag: Int): Double {
            if (lag <= 0 || lag >= n / 2) return 0.0
            var s = 0.0
            for (i in 0 until n - lag) s += (o[i] * o[i + lag]).toDouble()
            return s / (n - lag)
        }

        val minLag = 33 // 180 BPM
        val maxLag = 86 // ~70 BPM
        var best = 0.0
        var bestLag = 0
        val sc = DoubleArray(maxLag + 2)
        for (lag in minLag..maxLag) {
            sc[lag] = score(lag) + 0.5 * score(lag * 2)
            if (sc[lag] > best) {
                best = sc[lag]
                bestLag = lag
            }
        }
        if (bestLag == 0 || best <= 0.0) return 0.0
        var l = bestLag.toDouble()
        if (bestLag > minLag && bestLag < maxLag) {
            val a = sc[bestLag - 1]
            val b = sc[bestLag]
            val c = sc[bestLag + 1]
            val d = a - 2 * b + c
            if (abs(d) > 1e-12) l += 0.5 * (a - c) / d
        }
        var bpm = 6000.0 / l
        while (bpm < 75) bpm *= 2
        while (bpm >= 160) bpm /= 2
        return bpm
    }
}
