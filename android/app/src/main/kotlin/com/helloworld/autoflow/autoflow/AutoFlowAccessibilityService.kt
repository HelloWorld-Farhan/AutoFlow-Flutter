package com.helloworld.autoflow.autoflow

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Path
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.app.KeyguardManager
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONObject
import org.json.JSONArray

class AutoFlowAccessibilityService : AccessibilityService(), SharedPreferences.OnSharedPreferenceChangeListener {

    companion object {
        private const val TAG = "AutoFlowAccessibility"
        var instance: AutoFlowAccessibilityService? = null
    }

    private lateinit var prefs: SharedPreferences
    
    // State variables
    private var isAutomating = false
    private var currentTaskType = ""
    private var targetContact = ""
    private var messagePayload = ""
    private var automationStep = 0
    private var macroActionsJson = ""
    private var isPickingContact = false
    private var pickingPlatform = ""
    
    // Wake Lock
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d(TAG, "Accessibility Service Connected")
        
        // Listen to Flutter's SharedPreferences
        prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.registerOnSharedPreferenceChangeListener(this)
    }

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        prefs.unregisterOnSharedPreferenceChangeListener(this)
        Log.d(TAG, "Accessibility Service Unbound")
        return super.onUnbind(intent)
    }
    
    override fun onSharedPreferenceChanged(sharedPreferences: SharedPreferences?, key: String?) {
        if (key == "flutter_pending_automation") {
            val payload = sharedPreferences?.getString(key, null)
            if (payload != null && payload.isNotEmpty()) {
                Log.d(TAG, "Received pending automation: \$payload")
                try {
                    val json = JSONObject(payload)
                    currentTaskType = json.optString("taskType")
                    targetContact = json.optString("target")
                    messagePayload = json.optString("payload")
                    val macroId = json.optInt("macroId", -1)
                    
                    // Clear the pending automation so it doesn't run twice
                    sharedPreferences.edit().remove(key).apply()
                    
                    startAutomationSequence()
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to parse automation payload", e)
                }
            }
        }
        
    }

    fun startContactPicker(platform: String) {
        if (platform.isNotEmpty()) {
            isPickingContact = true
            pickingPlatform = platform
            Log.d(TAG, "Starting contact picker via MethodChannel for $platform")
            
            var packageName = ""
            when (platform) {
                "whatsapp" -> packageName = "com.whatsapp"
                "instagram" -> packageName = "com.instagram.android"
                "snapchat" -> packageName = "com.snapchat.android"
            }
            
            if (packageName.isNotEmpty()) {
                val intent = packageManager.getLaunchIntentForPackage(packageName)
                if (intent != null) {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                }
            }
        }
    }

    private fun startAutomationSequence() {
        isAutomating = true
        automationStep = 0
        
        wakeDevice()
        
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (keyguardManager.isKeyguardLocked) {
            Log.d(TAG, "Device is locked. Starting SKEDit style unlock sequence...")
            performUnlockSequence()
        } else {
            Log.d(TAG, "Device is unlocked. Proceeding directly to app.")
            launchTargetApp()
        }
    }
    
    private fun wakeDevice() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
            "AutoFlow::WakeLock"
        )
        wakeLock?.acquire(3 * 60 * 1000L /*3 minutes*/)
    }
    
    private fun performUnlockSequence() {
        // 1. Swipe up to reveal PIN pad
        val path = Path()
        path.moveTo(500f, 2000f)
        path.lineTo(500f, 500f)
        val gestureBuilder = GestureDescription.Builder()
        gestureBuilder.addStroke(GestureDescription.StrokeDescription(path, 0, 500))
        dispatchGesture(gestureBuilder.build(), object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                Log.d(TAG, "Swipe up completed. Waiting for keypad...")
                
                Handler(Looper.getMainLooper()).postDelayed({
                    enterPin()
                }, 1000)
            }
        }, null)
    }
    
    private fun enterPin() {
        val pin = prefs.getString("flutter.lockscreen_pin", "")
        if (pin.isNullOrEmpty()) {
            Log.e(TAG, "No PIN stored! Cannot unlock device.")
            isAutomating = false
            return
        }
        
        // This is a simplified logic. In reality, we must find node info for PIN numbers
        // or click standard coordinates. Here we simulate finding nodes by text.
        Log.d(TAG, "Typing PIN: \$pin")
        
        // Let's use coordinates as a fallback mechanism for Samsung phones if nodes aren't found
        // 1, 2, 3
        // 4, 5, 6
        // 7, 8, 9
        //    0, OK
        
        // Attempt to find password EditText for complex passwords
        val root = rootInActiveWindow
        if (root != null) {
            val passwordNodes = root.findAccessibilityNodeInfosByViewId("com.android.systemui:id/passwordEntry")
            if (passwordNodes.isNotEmpty()) {
                val args = Bundle()
                args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, pin)
                passwordNodes[0].performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
                Handler(Looper.getMainLooper()).postDelayed({
                    // Press Enter on keyboard by dispatching key event or clicking ok
                    clickNodeByText("OK")
                    clickNodeByText("Done")
                    Handler(Looper.getMainLooper()).postDelayed({
                        launchTargetApp()
                    }, 1000)
                }, 500)
                return
            }
        }
        
        // Fallback to numeric PIN tapping
        var delay = 0L
        for (digit in pin) {
            Handler(Looper.getMainLooper()).postDelayed({
                clickNodeByText(digit.toString())
            }, delay)
            delay += 300
        }
        
        Handler(Looper.getMainLooper()).postDelayed({
            clickNodeByText("OK")
            
            Handler(Looper.getMainLooper()).postDelayed({
                launchTargetApp()
            }, 1000)
        }, delay + 300)
    }
    
    private fun clickNodeByText(text: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val nodes = root.findAccessibilityNodeInfosByText(text)
        for (node in nodes) {
            if (node.isClickable) {
                node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                return true
            }
        }
        return false
    }

    private fun launchTargetApp() {
        val packageName = when (currentTaskType) {
            "whatsapp" -> "com.whatsapp"
            "instagram" -> "com.instagram.android"
            "snapchat" -> "com.snapchat.android"
            else -> null
        }
        
        if (packageName != null) {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                startActivity(intent)
                automationStep = 1
                Log.d(TAG, "Launched \$packageName, step = 1")
            } else {
                Log.e(TAG, "App not installed: \$packageName")
                isAutomating = false
            }
        } else if (currentTaskType == "workflow") {
            Log.d(TAG, "Starting Custom Workflow macro replay")
            automationStep = 1
            replayMacro()
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        if (isPickingContact) {
            val pkg = event.packageName?.toString() ?: ""
            val isTargetApp = pkg == "com.whatsapp" || pkg == "com.instagram.android" || pkg == "com.snapchat.android"

            // Primary strategy: catch clicks on contact rows (e.g., search results or home screen)
            if (isTargetApp && event.eventType == AccessibilityEvent.TYPE_VIEW_CLICKED) {
                val node = event.source ?: return
                // Check if the node they clicked or its parent has a valid name
                var name = getFirstMeaningfulText(node)
                if (name == null && node.parent != null) {
                    name = getFirstMeaningfulText(node.parent)
                }
                
                if (name != null) {
                    Log.d(TAG, "[Strategy3] Contact from clicked node: $name")
                    sendContactBack(name)
                }
                return
            }
        }

        if (!isAutomating) return
        val rootNode = rootInActiveWindow ?: return

        when (currentTaskType) {
            "whatsapp" -> handleWhatsAppAutomation(rootNode)
            "instagram" -> handleInstagramAutomation(rootNode)
            "snapchat" -> handleSnapchatAutomation(rootNode)
        }
    }

    private fun tryExtractFromConversationHeader(root: AccessibilityNodeInfo, pkg: String): Boolean {
        // Platform-specific title bar IDs for the conversation/chat open screen
        val titleIds = when (pkg) {
            "com.whatsapp" -> listOf(
                "com.whatsapp:id/conversation_contact_name",
                "com.whatsapp:id/toolbar_title",
                "com.whatsapp:id/contact_name"
            )
            "com.instagram.android" -> listOf(
                "com.instagram.android:id/action_bar_title",
                "com.instagram.android:id/direct_thread_title_type",
                "com.instagram.android:id/row_inbox_username"
            )
            "com.snapchat.android" -> listOf(
                "com.snapchat.android:id/chat_input_bar_title",
                "com.snapchat.android:id/action_bar_title",
                "com.snapchat.android:id/feed_display_name"
            )
            else -> emptyList()
        }

        for (id in titleIds) {
            val nodes = root.findAccessibilityNodeInfosByViewId(id)
            for (node in nodes) {
                val text = node.text?.toString()
                if (!text.isNullOrEmpty() && !isBadKeyword(text)) {
                    Log.d(TAG, "[Header] Contact from conversation header: $text")
                    return sendContactBack(text)
                }
            }
        }
        return false
    }

    
    private fun handleWhatsAppAutomation(rootNode: AccessibilityNodeInfo) {
        when (automationStep) {
            1 -> {
                val searchIcon = rootNode.findAccessibilityNodeInfosByViewId("com.whatsapp:id/menuitem_search")
                if (searchIcon.isNotEmpty()) {
                    searchIcon[0].performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    automationStep = 2
                }
            }
            2 -> {
                val searchInput = rootNode.findAccessibilityNodeInfosByViewId("com.whatsapp:id/search_src_text")
                if (searchInput.isNotEmpty()) {
                    val arguments = Bundle()
                    arguments.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, targetContact)
                    searchInput[0].performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
                    automationStep = 3
                }
            }
            3 -> {
                val contactResult = rootNode.findAccessibilityNodeInfosByViewId("com.whatsapp:id/contact_row_container")
                if (contactResult.isNotEmpty()) {
                    contactResult[0].performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    automationStep = 4
                }
            }
            4 -> {
                val messageInput = rootNode.findAccessibilityNodeInfosByViewId("com.whatsapp:id/entry")
                if (messageInput.isNotEmpty()) {
                    val arguments = Bundle()
                    arguments.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, messagePayload)
                    messageInput[0].performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
                    automationStep = 5
                }
            }
            5 -> {
                val sendButton = rootNode.findAccessibilityNodeInfosByViewId("com.whatsapp:id/send")
                if (sendButton.isNotEmpty()) {
                    sendButton[0].performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    automationStep = 6
                    finishAutomation()
                }
            }
        }
    }

    private val badKeywords = listOf(
        "search", "type a message", "new chat", "camera", "more options",
        "attach", "voice message", "status", "calls", "chats", "communities",
        "whatsapp", "instagram", "snapchat", "meta", "friends"
    )

    // Removed extractContactNameFromScreen as it was too aggressive

    private fun getFirstMeaningfulText(node: AccessibilityNodeInfo): String? {
        val cls = node.className?.toString() ?: ""
        if (cls.contains("EditText")) return null
        val text = node.text?.toString()
        if (!text.isNullOrEmpty() && text.length > 1 && !isBadKeyword(text)) return text
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val result = getFirstMeaningfulText(child)
            if (result != null) return result
        }
        return null
    }

    private fun isBadKeyword(text: String): Boolean {
        val lower = text.lowercase()
        return badKeywords.any { lower.contains(it) }
    }

    private fun sendContactBack(contactName: String): Boolean {
        Log.d(TAG, "Contact picked: $contactName")
        isPickingContact = false
        prefs.edit().putString("flutter.flutter_contact_picked", contactName).apply()
        val intent = packageManager.getLaunchIntentForPackage("com.helloworld.autoflow.autoflow")
        if (intent != null) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            startActivity(intent)
        }
        return true
    }

    private fun handleInstagramAutomation(rootNode: AccessibilityNodeInfo) {
        // High level Instagram logic
        when (automationStep) {
            1 -> {
                val dmIcon = rootNode.findAccessibilityNodeInfosByViewId("com.instagram.android:id/action_bar_inbox_button")
                if (dmIcon.isNotEmpty()) {
                    dmIcon[0].performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    automationStep = 2
                }
            }
            // Add subsequent IG steps here...
            2 -> {
                finishAutomation()
            }
        }
    }

    private fun handleSnapchatAutomation(rootNode: AccessibilityNodeInfo) {
        // High level Snapchat logic
        when (automationStep) {
            1 -> {
                val cameraButton = rootNode.findAccessibilityNodeInfosByViewId("com.snapchat.android:id/camera_capture_button")
                if (cameraButton.isNotEmpty()) {
                    cameraButton[0].performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    automationStep = 2
                }
            }
            // Add subsequent Snap steps here...
            2 -> {
                finishAutomation()
            }
        }
    }
    
    private fun replayMacro() {
        // Parse macroActionsJson and dispatch gestures recursively
        Log.d(TAG, "Replaying macro actions: \$macroActionsJson")
        // ... gesture description logic
        finishAutomation()
    }

    private fun finishAutomation() {
        Log.d(TAG, "Automation finished successfully!")
        isAutomating = false
        automationStep = 0
        wakeLock?.release()
    }

    override fun onInterrupt() {
        Log.e(TAG, "Accessibility Service Interrupted")
        isAutomating = false
    }
}
