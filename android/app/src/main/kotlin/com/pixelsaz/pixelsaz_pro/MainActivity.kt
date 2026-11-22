package com.pixelsaz.pixelsaz_pro

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import androidx.core.content.FileProvider
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.media.ExifInterface
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.UUID
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/** Native Android JPEG encoder. The source bitmap is decoded once per item. */
class MainActivity : FlutterActivity() {
    private val workers = Executors.newFixedThreadPool(3)
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pixelsaz_pro/native_image")
            .setMethodCallHandler { call, reply ->
                if (call.method != "encode") {
                    reply.notImplemented()
                    return@setMethodCallHandler
                }
                val args = call.arguments as? Map<*, *>
                if (args == null) {
                    reply.error("invalid_arguments", "The encoder requires argument map.", null)
                    return@setMethodCallHandler
                }
                workers.execute {
                    try {
                        val result = encode(args)
                        mainHandler.post { reply.success(result) }
                    } catch (error: Throwable) {
                        val code = if (error is OutOfMemoryError) "out_of_memory" else "native_encode_failed"
                        mainHandler.post { reply.error(code, error.message ?: "Native conversion failed", null) }
                    }
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pixelsaz_pro/zip_share")
            .setMethodCallHandler { call, reply ->
                if (call.method != "shareToBale") {
                    reply.notImplemented()
                    return@setMethodCallHandler
                }
                val arguments = call.arguments as? Map<*, *>
                if (arguments == null) {
                    reply.error("invalid_arguments", "Expected ZIP path arguments.", null)
                    return@setMethodCallHandler
                }
                try {
                    reply.success(shareZipToBale(arguments))
                } catch (error: Exception) {
                    reply.error("zip_share_failed", error.message ?: "Unable to share ZIP", null)
                }
            }
    }

    /**
     * Open Bale directly when it handles application/zip. The Dart caller
     * falls back to the system share sheet when Bale is missing.
     */
    private fun shareZipToBale(arguments: Map<*, *>): Boolean {
        val requestedPath = arguments["zipPath"] as? String
            ?: throw IllegalArgumentException("Missing ZIP path")
        val root = File(cacheDir, "pixelsaz_pro").canonicalFile
        val archive = File(requestedPath).canonicalFile
        if (!archive.path.startsWith(root.path + File.separator)) {
            throw SecurityException("Only generated ZIP cache entries may be shared")
        }
        if (!archive.isFile || !archive.name.endsWith(".zip", ignoreCase = true) ||
            archive.length() <= 0L) {
            throw IllegalArgumentException("Generated ZIP is missing or empty")
        }
        val uri = FileProvider.getUriForFile(
            this, applicationContext.packageName + ".zip_share_provider", archive
        )
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "application/zip"
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newRawUri(archive.name, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            setPackage("ir.nasim")
        }
        return try {
            startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }

    override fun onDestroy() {
        workers.shutdown()
        super.onDestroy()
    }

    private fun intArg(args: Map<*, *>, name: String, default: Int): Int =
        (args[name] as? Number)?.toInt() ?: default

    private fun boolArg(args: Map<*, *>, name: String, default: Boolean): Boolean =
        (args[name] as? Boolean) ?: default

    private fun encode(args: Map<*, *>): Map<String, Any> {
        val sourcePath = args["inputPath"] as? String
            ?: throw IllegalArgumentException("Missing inputPath")
        val file = File(sourcePath)
        if (!file.isFile || file.length() <= 0L || file.length() > 120L * 1024 * 1024) {
            throw IllegalArgumentException("Input file missing, empty or over 120 MB")
        }
        val idPhoto = boolArg(args, "idPhoto", false)
        val minQuality = intArg(args, "minQuality", 65).coerceIn(1, 100)
        val maxQuality = intArg(args, "maxQuality", 98).coerceIn(minQuality, 100)
        val resizeTriggerQuality = intArg(args, "resizeTriggerQuality", 72).coerceIn(minQuality, maxQuality)
        val minShortEdge = intArg(args, "minShortEdge", 160).coerceAtLeast(32)
        val targetBytes = (args["targetBytes"] as? Number)?.toInt()?.takeIf { it > 0 }
        val inputFormat = (args["sourceFormat"] as? String) ?: "unknown"

        var image = decodeImage(file, idPhoto)
        var resizeCount = 0
        try {
            if (idPhoto) {
                val source = image
                image = cropAndResizeIdPhoto(source)
                if (image !== source) source.recycle()
            } else if (image.width > 8000 || image.height > 8000 ||
                image.width.toLong() * image.height.toLong() > 28000000L) {
                val source = image
                val scale = min(1.0, sqrt(28000000.0 / (image.width.toDouble() * image.height)))
                val width = max(1, (image.width * scale).roundToInt())
                val height = max(1, (image.height * scale).roundToInt())
                image = Bitmap.createScaledBitmap(source, width, height, true)
                if (image !== source) source.recycle()
                resizeCount++
            }

            val originalWidth = image.width
            val originalHeight = image.height
            val guesses = if (targetBytes == null) maxQuality else {
                val ratio = file.length().toDouble() / targetBytes
                when {
                    ratio >= 12 -> 75
                    ratio >= 5 -> 82
                    ratio >= 2 -> 88
                    else -> 94
                }.coerceIn(minQuality, maxQuality)
            }
            var attempts = 0
            var best: Candidate? = null
            fun consider(bitmap: Bitmap, quality: Int, resized: Int) {
                val bytes = encodeBitmap(bitmap, quality)
                attempts++
                val c = Candidate(bytes, quality, bitmap.width, bitmap.height, resized)
                if (best == null || targetBytes == null ||
                    (c.bytes.size <= targetBytes &&
                        (best!!.bytes.size > targetBytes || c.bytes.size > best!!.bytes.size)) ||
                    (best!!.bytes.size > targetBytes && c.bytes.size < best!!.bytes.size)) {
                    best = c
                }
            }

            consider(image, guesses, resizeCount)
            if (targetBytes != null) {
                val firstSize = best!!.bytes.size
                val lowerBound = (targetBytes * 0.92).roundToInt()
                if (firstSize > targetBytes) {
                    val secondQuality = resizeTriggerQuality.coerceAtMost(guesses)
                    if (secondQuality != guesses) consider(image, secondQuality, resizeCount)
                    val second = best!!
                    if (second.bytes.size > targetBytes && attempts < 3 && !idPhoto) {
                        val minEdge = min(image.width, image.height)
                        if (minEdge > minShortEdge) {
                            val ratio = sqrt(targetBytes.toDouble() / second.bytes.size) * 0.91
                            val scale = max(minShortEdge.toDouble() / minEdge, min(0.97, ratio))
                            val width = max(1, (image.width * scale).roundToInt())
                            val height = max(1, (image.height * scale).roundToInt())
                            val scaled = Bitmap.createScaledBitmap(image, width, height, true)
                            if (scaled !== image) {
                                image.recycle()
                                image = scaled
                                resizeCount++
                            }
                            consider(image, secondQuality, resizeCount)
                        }
                    } else if (second.bytes.size < lowerBound && attempts < 3) {
                        val thirdQuality = ((guesses + secondQuality) / 2).coerceIn(minQuality, maxQuality)
                        if (thirdQuality != secondQuality) consider(image, thirdQuality, resizeCount)
                    }
                } else if (firstSize < lowerBound && guesses < maxQuality) {
                    consider(image, maxQuality, resizeCount)
                    val second = best!!
                    if (attempts < 3 && second.bytes.size > targetBytes) {
                        val factor = targetBytes.toDouble() / second.bytes.size
                        val q = (minQuality + (maxQuality - minQuality) * factor).roundToInt()
                            .coerceIn(minQuality, maxQuality)
                        if (q != maxQuality && q != guesses) consider(image, q, resizeCount)
                    }
                }
            }

            val chosen = best ?: throw IllegalStateException("JPEG encoder returned no output")
            val outputDir = File(cacheDir, "pixelsaz_fast_native")
            if (!outputDir.exists() && !outputDir.mkdirs()) {
                throw IllegalStateException("Unable to create native output directory")
            }
            val outputFile = File(outputDir, "${UUID.randomUUID()}.jpg")
            outputFile.writeBytes(chosen.bytes)
            return mapOf(
                "path" to outputFile.absolutePath,
                "width" to chosen.width,
                "height" to chosen.height,
                "quality" to chosen.quality,
                "resizeCount" to chosen.resizes,
                "passCount" to attempts,
                "targetReached" to (targetBytes == null || chosen.bytes.size <= targetBytes),
                "sourceFormat" to inputFormat,
                "decodedWidth" to originalWidth,
                "decodedHeight" to originalHeight
            )
        } finally {
            if (!image.isRecycled) image.recycle()
        }
    }

    private data class Candidate(
        val bytes: ByteArray,
        val quality: Int,
        val width: Int,
        val height: Int,
        val resizes: Int
    )

    private fun encodeBitmap(bitmap: Bitmap, quality: Int): ByteArray {
        val stream = ByteArrayOutputStream()
        if (!bitmap.compress(Bitmap.CompressFormat.JPEG, quality, stream)) {
            throw IllegalStateException("Bitmap.compress returned false")
        }
        return stream.toByteArray()
    }

    private fun decodeImage(file: File, idPhoto: Boolean): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, bounds)
        val raw: Bitmap = if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            decodeBmp(file) ?: throw IllegalArgumentException("Unsupported or damaged image")
        } else {
            var sample = 1
            val targetPixels = if (idPhoto) 2500000L else 6000000L
            while ((bounds.outWidth.toLong() / sample) * (bounds.outHeight.toLong() / sample) > targetPixels) {
                sample *= 2
            }
            val options = BitmapFactory.Options().apply {
                inSampleSize = sample
                inPreferredConfig = Bitmap.Config.ARGB_8888
                inMutable = false
            }
            BitmapFactory.decodeFile(file.absolutePath, options)
                ?: throw IllegalArgumentException("Platform decoder could not read image")
        }
        val orientation = try {
            ExifInterface(file.absolutePath).getAttributeInt(
                ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL
            )
        } catch (_: Exception) { ExifInterface.ORIENTATION_NORMAL }
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> { matrix.postRotate(90f); matrix.postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_TRANSVERSE -> { matrix.postRotate(270f); matrix.postScale(-1f, 1f) }
        }
        val oriented = if (matrix.isIdentity) raw else Bitmap.createBitmap(
            raw, 0, 0, raw.width, raw.height, matrix, true
        ).also { if (it !== raw) raw.recycle() }
        val background = Bitmap.createBitmap(oriented.width, oriented.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(background)
        canvas.drawColor(Color.WHITE)
        canvas.drawBitmap(oriented, 0f, 0f, Paint(Paint.FILTER_BITMAP_FLAG))
        oriented.recycle()
        return background
    }

    private fun cropAndResizeIdPhoto(image: Bitmap): Bitmap {
        val desiredRatio = 3.0 / 4.0
        var cropWidth = image.width
        var cropHeight = image.height
        val ratio = cropWidth.toDouble() / cropHeight
        if (ratio > desiredRatio) cropWidth = max(1, (cropHeight * desiredRatio).roundToInt())
        else cropHeight = max(1, (cropWidth / desiredRatio).roundToInt())
        val left = (image.width - cropWidth) / 2
        val top = (image.height - cropHeight) / 2
        val crop = Bitmap.createBitmap(image, left, top, cropWidth, cropHeight)
        val scaled = Bitmap.createScaledBitmap(crop, 354, 472, true)
        if (crop !== image && crop !== scaled) crop.recycle()
        return scaled
    }

    /** Uncompressed, 24/32-bit Windows BMP fallback for legacy input files. */
    private fun decodeBmp(file: File): Bitmap? {
        val bytes = file.readBytes()
        if (bytes.size < 54 || bytes[0] != 0x42.toByte() || bytes[1] != 0x4D.toByte()) return null
        val data = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        val pixelOffset = data.getInt(10)
        val width = data.getInt(18)
        val rawHeight = data.getInt(22)
        val bpp = data.getShort(28).toInt() and 0xFFFF
        val compression = data.getInt(30)
        if (width <= 0 || rawHeight == 0 || abs(rawHeight.toLong()) > 100000 ||
            width.toLong() * abs(rawHeight.toLong()) > 28000000L ||
            (bpp != 24 && bpp != 32) || compression != 0) return null
        val height = abs(rawHeight)
        val stride = ((width.toLong() * bpp + 31) / 32 * 4).toInt()
        if (pixelOffset < 54 || pixelOffset.toLong() + stride.toLong() * height > bytes.size) return null
        val colors = IntArray(width * height)
        val bytesPerPixel = bpp / 8
        for (y in 0 until height) {
            val srcY = if (rawHeight > 0) height - 1 - y else y
            var position = pixelOffset + srcY * stride
            for (x in 0 until width) {
                val b = bytes[position].toInt() and 0xFF
                val g = bytes[position + 1].toInt() and 0xFF
                val r = bytes[position + 2].toInt() and 0xFF
                colors[y * width + x] = Color.rgb(r, g, b)
                position += bytesPerPixel
            }
        }
        return Bitmap.createBitmap(colors, width, height, Bitmap.Config.ARGB_8888)
    }
}
