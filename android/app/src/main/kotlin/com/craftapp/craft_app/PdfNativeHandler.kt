package com.craftapp.craft_app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import androidx.security.crypto.EncryptedFile
import androidx.security.crypto.MasterKey
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.*
import com.tom_roush.pdfbox.pdmodel.common.PDRectangle
import com.tom_roush.pdfbox.pdmodel.encryption.AccessPermission
import com.tom_roush.pdfbox.pdmodel.encryption.StandardProtectionPolicy
import com.tom_roush.pdfbox.pdmodel.font.PDType0Font
import com.tom_roush.pdfbox.pdmodel.graphics.image.PDImageXObject
import com.tom_roush.pdfbox.rendering.ImageType
import com.tom_roush.pdfbox.rendering.PDFRenderer
import com.tom_roush.pdfbox.text.PDFTextStripper
import java.io.*
import java.security.SecureRandom
import kotlin.math.max
import kotlin.math.min

class PdfNativeHandler(private val context: Context) {
    companion object {
        const val CHANNEL = "com.craftapp/pdf_native"
        private const val TAG = "PdfNativeHandler"

        fun setup(flutterEngine: FlutterEngine, context: Context) {
            val handler = PdfNativeHandler(context)
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            channel.setMethodCallHandler { call, result ->
                handler.handle(call, result)
            }
        }
    }

    init {
        PDFBoxResourceLoader.init(context)
    }

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                when (call.method) {
                    "mergePdfs" -> mergePdfs(call, result)
                    "splitPdf" -> splitPdf(call, result)
                    "compressPdf" -> compressPdf(call, result)
                    "encryptPdf" -> encryptPdf(call, result)
                    "decryptPdf" -> decryptPdf(call, result)
                    "extractText" -> extractText(call, result)
                    "pdfToImages" -> pdfToImages(call, result)
                    "imagesToPdf" -> imagesToPdf(call, result)
                    "rotatePages" -> rotatePages(call, result)
                    "deletePages" -> deletePages(call, result)
                    "reorderPages" -> reorderPages(call, result)
                    "extractPages" -> extractPages(call, result)
                    "addWatermark" -> addWatermark(call, result)
                    "flattenPdf" -> flattenPdf(call, result)
                    "getPageCount" -> getPageCount(call, result)
                    "getPdfInfo" -> getPdfInfo(call, result)
                    "encryptFile" -> encryptFile(call, result)
                    "decryptFile" -> decryptFile(call, result)
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("PDF_ERROR", e.message ?: "Unknown error", null)
            }
        }
    }

    // ─── MERGE PDFs ─────────────────────────────────────────────────────────

    private fun mergePdfs(call: MethodCall, result: MethodChannel.Result) {
        val paths = call.argument<List<String>>("paths") ?: throw IllegalArgumentException("paths required")
        val outputPath = call.argument<String>("outputPath") ?: throw IllegalArgumentException("outputPath required")

        val merged = PDDocument()
        for (path in paths) {
            val doc = PDDocument.load(File(path))
            for (i in 0 until doc.numberOfPages) {
                merged.addPage(doc.getPage(i))
            }
            doc.close()
        }
        merged.save(outputPath)
        merged.close()
        result.success(outputPath)
    }

    // ─── SPLIT PDF ──────────────────────────────────────────────────────────

    private fun splitPdf(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path") ?: throw IllegalArgumentException("path required")
        val outputDir = call.argument<String>("outputDir") ?: throw IllegalArgumentException("outputDir required")
        val ranges = call.argument<List<List<Int>>>("ranges") // [[start, end], ...]

        val doc = PDDocument.load(File(path))
        val outputs = mutableListOf<String>()

        if (ranges != null) {
            for ((idx, range) in ranges.withIndex()) {
                val start = range[0] - 1
                val end = min(range[1], doc.numberOfPages)
                val split = PDDocument()
                for (i in start until end) {
                    split.addPage(doc.getPage(i))
                }
                val outPath = "$outputDir/split_${idx + 1}.pdf"
                split.save(outPath)
                split.close()
                outputs.add(outPath)
            }
        } else {
            for (i in 0 until doc.numberOfPages) {
                val split = PDDocument()
                split.addPage(doc.getPage(i))
                val outPath = "$outputDir/page_${i + 1}.pdf"
                split.save(outPath)
                split.close()
                outputs.add(outPath)
            }
        }
        doc.close()
        result.success(outputs)
    }

    // ─── COMPRESS PDF ──────────────────────────────────────────────────────

    private fun compressPdf(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path") ?: throw IllegalArgumentException("path required")
        val quality = call.argument<Int>("quality") ?: 75

        val doc = PDDocument.load(File(path))
        val renderer = PDFRenderer(doc)

        val compressed = PDDocument()
        for (i in 0 until doc.numberOfPages) {
            val bitmap = renderer.renderImageWithDPI(i, quality * 0.72f, ImageType.RGB)
            val tmpFile = File(context.cacheDir, "tmp_page_$i.png")
            FileOutputStream(tmpFile).use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)
            }
            val img = PDImageXObject.createFromFileByExtension(tmpFile, compressed)
            val page = PDPage(PDRectangle.A4)
            compressed.addPage(page)
            val contentStream = PDPageContentStream(compressed, page)
            contentStream.drawImage(img, 0f, 0f, page.mediaBox.width, page.mediaBox.height)
            contentStream.close()
            tmpFile.delete()
            bitmap.recycle()
        }
        doc.close()

        val outPath = path.replace(".pdf", "_compressed.pdf")
        compressed.save(outPath)
        compressed.close()
        result.success(outPath)
    }

    // ─── ENCRYPT PDF ───────────────────────────────────────────────────────

    private fun encryptPdf(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path") ?: throw IllegalArgumentException("path required")
        val password = call.argument<String>("password") ?: throw IllegalArgumentException("password required")

        val doc = PDDocument.load(File(path))
        val permission = AccessPermission()
        permission.setCanModify(false)
        permission.setCanExtractContent(false)

        val policy = StandardProtectionPolicy(password, password, permission)
        policy.encryptionKeyLength = 256
        doc.protect(policy)
        doc.save(path.replace(".pdf", "_encrypted.pdf"))
        doc.close()
        result.success("PDF encrypted successfully")
    }

    // ─── DECRYPT PDF ───────────────────────────────────────────────────────

    private fun decryptPdf(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path") ?: throw IllegalArgumentException("path required")
        val password = call.argument<String>("password") ?: throw IllegalArgumentException("password required")

        val doc = PDDocument.load(File(path), password)
        // password already provided to load()
        doc.save(path.replace(".pdf", "_decrypted.pdf"))
        doc.close()
        result.success("PDF decrypted successfully")
    }

    // ─── EXTRACT TEXT ──────────────────────────────────────────────────────

    private fun extractText(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path") ?: throw IllegalArgumentException("path required")
        val doc = PDDocument.load(File(path))
        val stripper = PDFTextStripper()
        stripper.sortByPosition = true
        val text = stripper.getText(doc)
        doc.close()
        result.success(text)
    }

    // ─── PDF TO IMAGES ─────────────────────────────────────────────────────

    private fun pdfToImages(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path") ?: throw IllegalArgumentException("path required")
        val outputDir = call.argument<String>("outputDir") ?: throw IllegalArgumentException("outputDir required")
        val format = call.argument<String>("format") ?: "png"
        val dpi = call.argument<Int>("dpi") ?: 150

        val doc = PDDocument.load(File(path))
        val renderer = PDFRenderer(doc)
        val outputs = mutableListOf<String>()

        for (i in 0 until doc.numberOfPages) {
            val bitmap = renderer.renderImageWithDPI(i, dpi.toFloat(), ImageType.RGB)
            val ext = if (format == "jpg") "jpg" else "png"
            val compressFormat = if (format == "jpg") Bitmap.CompressFormat.JPEG else Bitmap.CompressFormat.PNG
            val outPath = "$outputDir/page_${i + 1}.$ext"
            FileOutputStream(outPath).use { out -> bitmap.compress(compressFormat, 95, out) }
            outputs.add(outPath)
            bitmap.recycle()
        }
        doc.close()
        result.success(outputs)
    }

    // ─── IMAGES TO PDF ─────────────────────────────────────────────────────

    private fun imagesToPdf(call: MethodCall, result: MethodChannel.Result) {
        val imagePaths = call.argument<List<String>>("imagePaths") ?: throw IllegalArgumentException("imagePaths required")
        val outputPath = call.argument<String>("outputPath") ?: throw IllegalArgumentException("outputPath required")

        val doc = PDDocument()
        for (imgPath in imagePaths) {
            val img = PDImageXObject.createFromFileByExtension(File(imgPath), doc)
            val page = PDPage(PDRectangle.A4)
            doc.addPage(page)
            val contentStream = PDPageContentStream(doc, page)
            val w = page.mediaBox.width
            val h = page.mediaBox.height
            val iw = img.width.toFloat()
            val ih = img.height.toFloat()
            val scale = min(w / iw, h / ih)
            val dx = (w - iw * scale) / 2f
            val dy = (h - ih * scale) / 2f
            contentStream.drawImage(img, dx, dy, iw * scale, ih * scale)
            contentStream.close()
        }
        doc.save(outputPath)
        doc.close()
        result.success(outputPath)
    }

    // ─── ROTATE PAGES ──────────────────────────────────────────────────────

    private fun rotatePages(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path") ?: throw IllegalArgumentException("path required")
        val rotation = call.argument<Int>("rotation") ?: 90
        val pages = call.argument<List<Int>>("pages") // null = all

        val doc = PDDocument.load(File(path))
        if (pages != null) {
            for (p in pages) {
                if (p in 1..doc.numberOfPages) doc.getPage(p - 1).rotation = rotation
            }
        } else {
            for (i in 0 until doc.numberOfPages) doc.getPage(i).rotation = rotation
        }
        doc.save(path.replace(".pdf", "_rotated.pdf"))
        doc.close()
        result.success("Pages rotated")
    }

    // ─── DELETE PAGES ──────────────────────────────────────────────────────

    private fun deletePages(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path") ?: throw IllegalArgumentException("path required")
        val pages = call.argument<List<Int>>("pages") ?: throw IllegalArgumentException("pages required")

        val doc = PDDocument.load(File(path))
        val sorted = pages.sortedDescending()
        for (p in sorted) {
            if (p in 1..doc.numberOfPages) doc.removePage(p - 1)
        }
        val outPath = path.replace(".pdf", "_trimmed.pdf")
        doc.save(outPath)
        doc.close()
        result.success(outPath)
    }

    // ─── REORDER PAGES ─────────────────────────────────────────────────────

    private fun reorderPages(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path") ?: throw IllegalArgumentException("path required")
        val newOrder = call.argument<List<Int>>("newOrder") ?: throw IllegalArgumentException("newOrder required")

        val doc = PDDocument.load(File(path))
        val reordered = PDDocument()
        for (p in newOrder) {
            if (p in 1..doc.numberOfPages) reordered.addPage(doc.getPage(p - 1))
        }
        doc.close()
        reordered.save(path.replace(".pdf", "_reordered.pdf"))
        reordered.close()
        result.success("Pages reordered")
    }

    // ─── EXTRACT PAGES ─────────────────────────────────────────────────────

    private fun extractPages(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path") ?: throw IllegalArgumentException("path required")
        val pages = call.argument<List<Int>>("pages") ?: throw IllegalArgumentException("pages required")

        val doc = PDDocument.load(File(path))
        val extracted = PDDocument()
        for (p in pages) {
            if (p in 1..doc.numberOfPages) extracted.addPage(doc.getPage(p - 1))
        }
        doc.close()
        val outPath = path.replace(".pdf", "_extracted.pdf")
        extracted.save(outPath)
        extracted.close()
        result.success(outPath)
    }

    // ─── ADD WATERMARK ─────────────────────────────────────────────────────

    private fun addWatermark(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path") ?: throw IllegalArgumentException("path required")
        val text = call.argument<String>("text") ?: throw IllegalArgumentException("text required")
        val opacity = call.argument<Float>("opacity") ?: 0.3f

        val doc = PDDocument.load(File(path))
        for (i in 0 until doc.numberOfPages) {
            val page = doc.getPage(i)
            val cs = PDPageContentStream(doc, page, PDPageContentStream.AppendMode.APPEND, true, true)
            cs.setNonStrokingColor(com.tom_roush.pdfbox.pdmodel.graphics.color.PDDeviceGray.INSTANCE.initialColor)
            cs.beginText()
            cs.newLineAtOffset(page.mediaBox.width / 4, page.mediaBox.height / 2)
            cs.setFont(PDType0Font.load(doc, javaClass.getResourceAsStream("/fonts/Helvetica.ttf")), 48f)
            cs.showText(text)
            cs.endText()
            cs.close()
        }
        doc.save(path.replace(".pdf", "_watermarked.pdf"))
        doc.close()
        result.success("Watermark added")
    }

    // ─── FLATTEN PDF ───────────────────────────────────────────────────────

    private fun flattenPdf(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path") ?: throw IllegalArgumentException("path required")

        val doc = PDDocument.load(File(path))
        // Flatten acroform
        val acroForm = doc.documentCatalog.acroForm
        if (acroForm != null) {
            acroForm.flatten()
        }
        val outPath = path.replace(".pdf", "_flattened.pdf")
        doc.save(outPath)
        doc.close()
        result.success(outPath)
    }

    // ─── GET PAGE COUNT ────────────────────────────────────────────────────

    private fun getPageCount(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path") ?: throw IllegalArgumentException("path required")
        val doc = PDDocument.load(File(path))
        result.success(doc.numberOfPages)
        doc.close()
    }

    // ─── GET PDF INFO ──────────────────────────────────────────────────────

    private fun getPdfInfo(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path") ?: throw IllegalArgumentException("path required")
        val doc = PDDocument.load(File(path))
        val info = doc.documentInformation
        val map = mutableMapOf<String, Any?>(
            "pageCount" to doc.numberOfPages,
            "title" to info.title,
            "author" to info.author,
            "subject" to info.subject,
            "creator" to info.creator,
            "producer" to info.producer,
            "isEncrypted" to doc.isEncrypted,
            "fileSize" to File(path).length(),
        )
        doc.close()
        result.success(map)
    }

    // ─── ENCRYPT FILE (AES-256) ────────────────────────────────────────────

    private fun encryptFile(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path") ?: throw IllegalArgumentException("path required")

        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()

        val encryptedFile = EncryptedFile.Builder(
            context,
            File(path),
            masterKey,
            EncryptedFile.FileEncryptionScheme.AES256_GCM_HKDF_4KB
        ).build()

        val input = File(path).readBytes()
        encryptedFile.openFileOutput().use { it.write(input) }
        File(path).delete()
        result.success("$path.enc")
    }

    private fun decryptFile(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path") ?: throw IllegalArgumentException("path required")

        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()

        val encryptedFile = EncryptedFile.Builder(
            context,
            File(path),
            masterKey,
            EncryptedFile.FileEncryptionScheme.AES256_GCM_HKDF_4KB
        ).build()

        val decrypted = encryptedFile.openFileInput().use { it.readBytes() }
        val outPath = path.removeSuffix(".enc")
        File(outPath).writeBytes(decrypted)
        result.success(outPath)
    }
}
