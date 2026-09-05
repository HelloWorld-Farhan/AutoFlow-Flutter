package com.helloworld.autoflow.autoflow

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.provider.Settings
import android.content.Context
import android.text.TextUtils

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.helloworld.autoflow/automation"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkAccessibilityPermission" -> {
                    val isEnabled = isAccessibilityServiceEnabled(context, AutoFlowAccessibilityService::class.java)
                    result.success(isEnabled)
                }
                "requestAccessibilityPermission" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    result.success(true)
                }
                "executeWhatsAppAutomation" -> {
                    val contact = call.argument<String>("contact")
                    val message = call.argument<String>("message")
                    
                    if (contact != null && message != null) {
                        if (AutoFlowAccessibilityService.instance != null) {
                            AutoFlowAccessibilityService.instance?.startWhatsAppAutomation(contact, message)
                            result.success(true)
                        } else {
                            result.error("UNAVAILABLE", "Accessibility Service not running.", null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "Contact or Message missing", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isAccessibilityServiceEnabled(context: Context, accessibilityService: Class<*>): Boolean {
        val expectedComponentName = android.content.ComponentName(context, accessibilityService)
        val enabledServicesSetting = Settings.Secure.getString(context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
            ?: return false
        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServicesSetting)
        while (colonSplitter.hasNext()) {
            val componentNameString = colonSplitter.next()
            val enabledService = android.content.ComponentName.unflattenFromString(componentNameString)
            if (enabledService != null && enabledService == expectedComponentName) {
                return true
            }
        }
        return false
    }
}
