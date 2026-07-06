package com.sinnoor.open_mail_launcher

import android.content.ClipData
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
        @Suppress("UNCHECKED_CAST")
        val emailContent = call.argument<Map<String, Any>>("emailContent")
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
    return getMailAppsForIntent(createMailAppQueryIntent())
  }

  private fun getMailAppsForIntent(emailIntent: Intent): List<Map<String, Any?>> {
    val packageManager = context.packageManager
    val resolveInfos = queryIntentActivities(emailIntent, packageManager)
    val defaultApp = resolveActivity(emailIntent, packageManager)
    val defaultPackageName = defaultApp?.activityInfo?.packageName
    
    return resolveInfos.distinctBy { it.activityInfo.packageName }.map { resolveInfo ->
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
    // No content means "open the mail app", not "compose an email" — so the
    // mailto: intent is used only to discover mail apps, never launched
    // directly in that case (issue #18).
    val composeIntent = emailContent?.let { createEmailIntent(it) }
    val mailApps = getMailAppsForIntent(composeIntent ?: createMailAppQueryIntent())

    if (mailApps.isEmpty()) {
      result.success(mapOf(
        "didOpen" to false,
        "canOpen" to false,
        "options" to emptyList<Map<String, Any?>>()
      ))
      return
    }

    try {
      if (mailApps.size == 1) {
        val packageName = mailApps[0]["id"] as String
        val launchIntent = if (composeIntent != null) {
          composeIntent.setPackage(packageName)
          composeIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
          composeIntent.takeIf { canResolveActivity(it) }
        } else {
          // A mailto: handler can lack a launcher activity (headless /
          // work-profile stub) — try the system email selector before
          // reporting "no apps" for an app we just discovered.
          createInboxIntent(packageName)
            ?: Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_EMAIL)
              .takeIf { canResolveActivity(it) }
        }
        if (launchIntent == null) {
          result.success(mapOf(
            "didOpen" to false,
            "canOpen" to false,
            "options" to emptyList<Map<String, Any?>>()
          ))
          return
        }
        context.startActivity(launchIntent)

        result.success(mapOf(
          "didOpen" to true,
          "canOpen" to true,
          "options" to mailApps
        ))
      } else {
        val chooserIntent = if (composeIntent != null) {
          // Android will show the chooser
          Intent.createChooser(composeIntent, "Choose Email App").also {
            copyAttachmentGrants(source = composeIntent, target = it)
          }
        } else {
          createInboxChooserIntent(mailApps)
        }
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

  /** Opens [packageName]'s main screen (inbox) rather than a compose window. */
  private fun createInboxIntent(packageName: String): Intent? {
    return context.packageManager.getLaunchIntentForPackage(packageName)
      ?.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
  }

  /**
   * System chooser over the discovered mail apps' main screens (inboxes).
   *
   * A bare CATEGORY_APP_EMAIL selector must NOT be startActivity'd here:
   * Android resolves it straight to the default handler without showing a
   * picker, and mailto: handlers often don't declare that category at all
   * (issue #18 regression). Instead, chooser over the apps we discovered.
   */
  private fun createInboxChooserIntent(mailApps: List<Map<String, Any?>>): Intent {
    // queryIntentActivities order is arbitrary — put the user's default
    // mailto: handler first so it becomes the chooser's base target.
    val ordered = mailApps.sortedByDescending { it["isDefault"] == true }
    val launchIntents = ordered.mapNotNull { createInboxIntent(it["id"] as String) }
    if (launchIntents.isEmpty()) {
      // Headless / work-profile stubs only — the selector is better than nothing.
      return Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_EMAIL)
    }
    if (launchIntents.size == 1) {
      return launchIntents[0]
    }
    // ponytail: ChooserActivity caps EXTRA_INITIAL_INTENTS at 2 on API 29+,
    // so at most 3 apps appear; fine until devices with 4+ mail apps show up.
    return Intent.createChooser(launchIntents[0], "Choose Email App").apply {
      putExtra(Intent.EXTRA_INITIAL_INTENTS, launchIntents.drop(1).toTypedArray())
    }
  }

  private fun openSpecificMailApp(appId: String, emailContent: Map<String, Any>?, result: Result) {
    try {
      // No content → open the app's inbox, not a compose window (issue #18).
      val intent = if (emailContent != null) {
        createEmailIntent(emailContent).apply {
          setPackage(appId)
          addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }.takeIf { canResolveActivity(it) }
      } else {
        createInboxIntent(appId)
      }

      if (intent != null) {
        context.startActivity(intent)
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
      copyAttachmentGrants(source = emailIntent, target = chooserIntent)
      
      if (canResolveActivity(emailIntent)) {
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
    return canResolveActivity(createMailAppQueryIntent())
  }

  private fun createEmailIntent(emailContent: Map<String, Any>): Intent {
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
      // For attachments switch to ACTION_SEND_MULTIPLE with `message/rfc822`
      // MIME so the chooser surfaces only email apps. `*/*` (pre-v0.2.0)
      // matched every share target on the device including Drive, Photos,
      // Messenger, Bluetooth — see audit C-12.
      //
      // FLAG_GRANT_READ_URI_PERMISSION is required for content:// URIs from
      // the caller's private file provider — without it the receiving mail
      // app gets SecurityException when trying to read the attachment.
      val sendIntent = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
        type = "message/rfc822"
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        putExtra(Intent.EXTRA_EMAIL, to.toTypedArray())
        if (cc.isNotEmpty()) putExtra(Intent.EXTRA_CC, cc.toTypedArray())
        if (bcc.isNotEmpty()) putExtra(Intent.EXTRA_BCC, bcc.toTypedArray())
        if (!subject.isNullOrEmpty()) putExtra(Intent.EXTRA_SUBJECT, subject)
        if (!body.isNullOrEmpty()) putExtra(Intent.EXTRA_TEXT, body)

        val uris = attachments.mapNotNull(::parseContentUri)

        if (uris.isNotEmpty()) {
          putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(uris))
          clipData = createAttachmentClipData(uris)
        }
      }
      return sendIntent
    }
    
    return intent
  }

  private fun createMailAppQueryIntent(): Intent {
    return Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:"))
  }

  private fun queryIntentActivities(
    intent: Intent,
    packageManager: PackageManager
  ): List<ResolveInfo> {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      packageManager.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0))
    } else {
      @Suppress("DEPRECATION")
      packageManager.queryIntentActivities(intent, 0)
    }
  }

  private fun resolveActivity(
    intent: Intent,
    packageManager: PackageManager
  ): ResolveInfo? {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      packageManager.resolveActivity(intent, PackageManager.ResolveInfoFlags.of(0))
    } else {
      @Suppress("DEPRECATION")
      packageManager.resolveActivity(intent, 0)
    }
  }

  private fun canResolveActivity(intent: Intent): Boolean {
    return resolveActivity(intent, context.packageManager) != null
  }

  private fun parseContentUri(value: String): Uri? {
    return try {
      Uri.parse(value).takeIf { it.scheme == "content" }
    } catch (e: Exception) {
      null
    }
  }

  private fun createAttachmentClipData(uris: List<Uri>): ClipData {
    val clipData = ClipData.newUri(context.contentResolver, "Email attachment", uris.first())
    uris.drop(1).forEach { uri ->
      clipData.addItem(ClipData.Item(uri))
    }
    return clipData
  }

  private fun copyAttachmentGrants(source: Intent, target: Intent) {
    source.clipData?.let { clipData ->
      target.clipData = clipData
      target.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
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
