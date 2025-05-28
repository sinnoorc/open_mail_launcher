package com.sinnoor.open_mail_launcher

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.util.Base64
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayOutputStream

/** OpenMailLauncherPlugin */
class OpenMailLauncherPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var context: Context

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "open_mail_launcher")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "getMailApps" -> {
        result.success(getMailApps())
      }
      "openMailApp" -> {
        val emailContent = call.arguments as? Map<String, Any>
        openMailApp(emailContent, result)
      }
      "openSpecificMailApp" -> {
        val appId = call.argument<String>("appId") ?: ""
        val emailContent = call.arguments as? Map<String, Any>
        openSpecificMailApp(appId, emailContent, result)
      }
      "composeEmail" -> {
        val emailContent = call.arguments as? Map<String, Any> ?: emptyMap()
        composeEmail(emailContent, result)
      }
      "isMailAppAvailable" -> {
        result.success(isMailAppAvailable())
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  private fun getMailApps(): List<Map<String, Any?>> {
    val emailIntent = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:"))
    val packageManager = context.packageManager
    
    val resolveInfos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      packageManager.queryIntentActivities(emailIntent, PackageManager.ResolveInfoFlags.of(0))
    } else {
      @Suppress("DEPRECATION")
      packageManager.queryIntentActivities(emailIntent, 0)
    }
    
    val defaultApp = packageManager.resolveActivity(emailIntent, 0)
    val defaultPackageName = defaultApp?.activityInfo?.packageName
    
    return resolveInfos.map { resolveInfo ->
      val packageName = resolveInfo.activityInfo.packageName
      mapOf(
        "name" to resolveInfo.loadLabel(packageManager).toString(),
        "id" to packageName,
        "icon" to getAppIconBase64(resolveInfo),
        "isDefault" to (packageName == defaultPackageName)
      )
    }
  }

  private fun openMailApp(emailContent: Map<String, Any>?, result: Result) {
    val mailApps = getMailApps()
    
    if (mailApps.isEmpty()) {
      result.success(mapOf(
        "didOpen" to false,
        "canOpen" to false,
        "options" to emptyList<Map<String, Any?>>()
      ))
      return
    }
    
    // If only one mail app or Android will handle the chooser
    val emailIntent = createEmailIntent(emailContent)
    
    try {
      if (mailApps.size == 1) {
        // Open directly
        emailIntent.setPackage(mailApps[0]["id"] as String)
        emailIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(emailIntent)
        
        result.success(mapOf(
          "didOpen" to true,
          "canOpen" to true,
          "options" to mailApps
        ))
      } else {
        // Android will show the chooser
        val chooserIntent = Intent.createChooser(emailIntent, "Choose Email App")
        chooserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(chooserIntent)
        
        result.success(mapOf(
          "didOpen" to true,
          "canOpen" to true,
          "options" to mailApps
        ))
      }
    } catch (e: Exception) {
      result.error("OPEN_MAIL_APP_ERROR", "Failed to open mail app: ${e.message}", null)
    }
  }

  private fun openSpecificMailApp(appId: String, emailContent: Map<String, Any>?, result: Result) {
    try {
      val emailIntent = createEmailIntent(emailContent)
      emailIntent.setPackage(appId)
      emailIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      
      if (emailIntent.resolveActivity(context.packageManager) != null) {
        context.startActivity(emailIntent)
        result.success(true)
      } else {
        result.success(false)
      }
    } catch (e: Exception) {
      result.success(false)
    }
  }

  private fun composeEmail(emailContent: Map<String, Any>, result: Result) {
    try {
      val emailIntent = createEmailIntent(emailContent)
      val chooserIntent = Intent.createChooser(emailIntent, "Send Email")
      chooserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      
      if (emailIntent.resolveActivity(context.packageManager) != null) {
        context.startActivity(chooserIntent)
        result.success(true)
      } else {
        result.success(false)
      }
    } catch (e: Exception) {
      result.success(false)
    }
  }

  private fun isMailAppAvailable(): Boolean {
    val emailIntent = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:"))
    return emailIntent.resolveActivity(context.packageManager) != null
  }

  private fun createEmailIntent(emailContent: Map<String, Any>?): Intent {
    if (emailContent == null) {
      return Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:"))
    }
    
    val uriBuilder = StringBuilder("mailto:")
    
    // Add recipients
    val to = emailContent["to"] as? List<String> ?: emptyList()
    uriBuilder.append(to.joinToString(","))
    
    val params = mutableListOf<String>()
    
    // Add CC
    val cc = emailContent["cc"] as? List<String> ?: emptyList()
    if (cc.isNotEmpty()) {
      params.add("cc=${cc.joinToString(",")}")
    }
    
    // Add BCC
    val bcc = emailContent["bcc"] as? List<String> ?: emptyList()
    if (bcc.isNotEmpty()) {
      params.add("bcc=${bcc.joinToString(",")}")
    }
    
    // Add subject
    val subject = emailContent["subject"] as? String
    if (!subject.isNullOrEmpty()) {
      params.add("subject=${Uri.encode(subject)}")
    }
    
    // Add body
    val body = emailContent["body"] as? String
    if (!body.isNullOrEmpty()) {
      params.add("body=${Uri.encode(body)}")
    }
    
    // Append parameters
    if (params.isNotEmpty()) {
      uriBuilder.append("?${params.joinToString("&")}")
    }
    
    val intent = Intent(Intent.ACTION_SENDTO, Uri.parse(uriBuilder.toString()))
    
    // Handle attachments if any
    val attachments = emailContent["attachments"] as? List<String> ?: emptyList()
    if (attachments.isNotEmpty()) {
      // For attachments, we need ACTION_SEND_MULTIPLE
      val sendIntent = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
        type = "*/*"
        putExtra(Intent.EXTRA_EMAIL, to.toTypedArray())
        if (cc.isNotEmpty()) putExtra(Intent.EXTRA_CC, cc.toTypedArray())
        if (bcc.isNotEmpty()) putExtra(Intent.EXTRA_BCC, bcc.toTypedArray())
        if (!subject.isNullOrEmpty()) putExtra(Intent.EXTRA_SUBJECT, subject)
        if (!body.isNullOrEmpty()) putExtra(Intent.EXTRA_TEXT, body)
        
        val uris = attachments.mapNotNull { path ->
          try {
            Uri.parse(path)
          } catch (e: Exception) {
            null
          }
        }
        
        if (uris.isNotEmpty()) {
          putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(uris))
        }
      }
      return sendIntent
    }
    
    return intent
  }

  private fun getAppIconBase64(resolveInfo: ResolveInfo): String? {
    return try {
      val icon = resolveInfo.loadIcon(context.packageManager)
      val bitmap = drawableToBitmap(icon)
      val outputStream = ByteArrayOutputStream()
      bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
      val bytes = outputStream.toByteArray()
      "data:image/png;base64,${Base64.encodeToString(bytes, Base64.NO_WRAP)}"
    } catch (e: Exception) {
      null
    }
  }

  private fun drawableToBitmap(drawable: Drawable): Bitmap {
    if (drawable is BitmapDrawable) {
      return drawable.bitmap
    }
    
    val bitmap = Bitmap.createBitmap(
      drawable.intrinsicWidth.coerceAtLeast(1),
      drawable.intrinsicHeight.coerceAtLeast(1),
      Bitmap.Config.ARGB_8888
    )
    
    val canvas = Canvas(bitmap)
    drawable.setBounds(0, 0, canvas.width, canvas.height)
    drawable.draw(canvas)
    
    return bitmap
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
