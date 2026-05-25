package com.sinnoor.open_mail_launcher

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.test.Test
import org.mockito.Mockito

/**
 * Local JVM unit tests for [OpenMailLauncherPlugin].
 *
 * The bulk of the plugin's logic — intent construction, PackageManager
 * queries, icon extraction — touches Android framework classes (Uri,
 * Intent, Bitmap, PackageManager) that are not available in plain
 * JUnit. Those paths are exercised end-to-end by the integration tests
 * under `example/integration_test/plugin_integration_test.dart`, which
 * run on a real device/emulator.
 *
 * Tests here cover only the method-channel dispatcher, which doesn't
 * require the Android runtime.
 *
 * Run from `example/android/`: `./gradlew testDebugUnitTest`
 */
internal class OpenMailLauncherPluginTest {

  @Test
  fun onMethodCall_unknownMethod_reportsNotImplemented() {
    val plugin = OpenMailLauncherPlugin()
    val call = MethodCall("methodThatDoesNotExist", null)
    val mockResult: MethodChannel.Result =
      Mockito.mock(MethodChannel.Result::class.java)

    plugin.onMethodCall(call, mockResult)

    Mockito.verify(mockResult).notImplemented()
    Mockito.verifyNoMoreInteractions(mockResult)
  }
}
