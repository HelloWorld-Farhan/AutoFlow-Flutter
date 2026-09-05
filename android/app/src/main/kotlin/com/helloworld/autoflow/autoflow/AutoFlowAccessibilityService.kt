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
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
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
            Log.d(TAG, "Device is unlocked. Proceeding to countdown.")
            showCountdownAndLaunch()
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
                        showCountdownAndLaunch()
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
                showCountdownAndLaunch()
            }, 1000)
        }, delay + 300)
    }
    
    private var overlayView: View? = null

    private fun showCountdownAndLaunch() {
        Handler(Looper.getMainLooper()).post {
            try {
                val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
                    PixelFormat.TRANSLUCENT
                )
                
                val layout = LinearLayout(this).apply {
                    orientation = LinearLayout.VERTICAL
                    gravity = Gravity.CENTER
                    setBackgroundColor(Color.parseColor("#E6000000")) // 90% black
                }
                
                val textTitle = TextView(this).apply {
                    text = "Automation Starting..."
                    textSize = 32f
                    setTextColor(Color.WHITE)
                    gravity = Gravity.CENTER
                }
                
                val textCountdown = TextView(this).apply {
                    text = "5"
                    textSize = 120f
                    setTextColor(Color.parseColor("#4A90E2")) // Blue
                    gravity = Gravity.CENTER
                    setTypeface(null, Typeface.BOLD)
                    setPadding(0, 40, 0, 0)
                }
                
                layout.addView(textTitle)
                layout.addView(textCountdown)
                
                wm.addView(layout, params)
                overlayView = layout
                
                var count = 5
                val handler = Handler(Looper.getMainLooper())
                val runnable = object : Runnable {
                    override fun run() {
                        count--
                        if (count > 0) {
                            textCountdown.text = count.toString()
                            handler.postDelayed(this, 1000)
                        } else {
                            try {
                                wm.removeView(layout)
                                overlayView = null
                            } catch (e: Exception) {}
                            launchTargetApp()
                        }
                    }
                }
                handler.postDelayed(runnable, 1000)
            } catch (e: Exception) {
                Log.e(TAG, "Error showing countdown: ", e)
                launchTargetApp()
            }
        }
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

            // Primary strategy: detect navigation into a conversation/chat screen (safety net)
            if (isTargetApp && event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
                // A new screen just opened in the target app - read the title
                Handler(Looper.getMainLooper()).postDelayed({
                    if (!isPickingContact) return@postDelayed
                    val root = rootInActiveWindow ?: return@postDelayed
                    tryExtractFromConversationHeader(root, pkg)
                }, 400) // small delay so the screen fully renders
                return
            }

            // Fallback: catch clicks on contact rows (e.g., search results or home screen)
            if (isTargetApp && event.eventType == AccessibilityEvent.TYPE_VIEW_CLICKED) {
                val node = event.source ?: return
                // Walk up to 10 levels to find the text (in case they tapped a nested profile picture in complex apps like Insta/Snap)
                var currentNode: AccessibilityNodeInfo? = node
                var name: String? = null
                var depth = 0
                while (currentNode != null && depth < 10) {
                    name = getFirstMeaningfulText(currentNode)
                    if (name != null) break
                    currentNode = currentNode.parent
                    depth++
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
                "com.whatsapp:id/conversation_contact_name"
            )
            "com.instagram.android" -> listOf(
                "com.instagram.android:id/header_subtitle",
                "com.instagram.android:id/direct_thread_title_type"
            )
            "com.snapchat.android" -> listOf(
                "com.snapchat.android:id/chat_input_bar_title",
                "com.snapchat.android:id/chat_header_title"
            )
            else -> emptyList()
        }

        for (id in titleIds) {
            val nodes = root.findAccessibilityNodeInfosByViewId(id)
            for (node in nodes) {
                val text = (node.text ?: node.contentDescription)?.toString()
                if (!text.isNullOrEmpty() && !isBadKeyword(text)) {
                    Log.d(TAG, "[Header] Contact from conversation header ID ($id): $text")
                    return sendContactBack(text)
                }
            }
        }

        // Smart Heuristic Fallback: If we couldn't find the exact ID (e.g. Insta/Snap updated their UI),
        // check if this is definitively a chat screen (has a message input).
        // If it is, the FIRST valid text on the screen (top-left) is almost always the contact's name!
        if (isChatScreen(root)) {
            val name = findFirstValidText(root)
            if (name != null) {
                Log.d(TAG, "[Header] Contact from heuristic top-text: $name")
                return sendContactBack(name)
            }
        }

        return false
    }

    private fun isChatScreen(root: AccessibilityNodeInfo): Boolean {
        val queue = java.util.ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        while (queue.isNotEmpty()) {
            val node = queue.poll() ?: continue
            val cls = node.className?.toString() ?: ""
            if (cls.contains("EditText")) return true
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let { queue.add(it) }
            }
        }
        return false
    }

    private fun findFirstValidText(root: AccessibilityNodeInfo): String? {
        val text = (root.text ?: root.contentDescription)?.toString()
        val cls = root.className?.toString() ?: ""
        if (!text.isNullOrEmpty() && text.length > 1 && !cls.contains("EditText") && !isBadKeyword(text)) {
            return text
        }
        for (i in 0 until root.childCount) {
            val child = root.getChild(i) ?: continue
            val result = findFirstValidText(child)
            if (result != null) return result
        }
        return null
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
        "whatsapp", "instagram", "snapchat", "meta", "friends", "back", "navigate up", "video call", "voice call"
    )

    // Removed extractContactNameFromScreen as it was too aggressive

    private fun getFirstMeaningfulText(node: AccessibilityNodeInfo): String? {
        val cls = node.className?.toString() ?: ""
        if (cls.contains("EditText")) return null
        var text = node.text?.toString()
        if (text.isNullOrEmpty()) {
            text = node.contentDescription?.toString()
        }
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

    private fun getAllNodes(root: AccessibilityNodeInfo): List<AccessibilityNodeInfo> {
        val list = mutableListOf<AccessibilityNodeInfo>()
        val queue = java.util.ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        while (queue.isNotEmpty()) {
            val node = queue.poll() ?: continue
            list.add(node)
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let { queue.add(it) }
            }
        }
        return list
    }

    private fun clickNode(node: AccessibilityNodeInfo?): Boolean {
        var current = node
        while (current != null) {
            if (current.isClickable) {
                current.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                return true
            }
            current = current.parent
        }
        return false
    }

    private fun handleInstagramAutomation(rootNode: AccessibilityNodeInfo) {
        val targetName = targetContactName ?: return
        val msg = scheduledMessage ?: return

        Log.d("AutoFlowAccessibility", "Instagram step: $automationStep")

        when (automationStep) {
            1 -> {
                // Find Inbox button (Phone or Tablet)
                val dmIcon = rootNode.findAccessibilityNodeInfosByViewId("com.instagram.android:id/action_bar_inbox_button") + 
                             rootNode.findAccessibilityNodeInfosByViewId("com.instagram.android:id/direct_tab")
                
                if (dmIcon.isNotEmpty()) {
                    Log.d("AutoFlowAccessibility", "Found dmIcon by ID")
                    if (clickNode(dmIcon[0])) {
                        Log.d("AutoFlowAccessibility", "Clicked dmIcon, moving to step 2")
                        automationStep = 2
                    }
                    return
                }
                
                // Fallback: search for Message or Direct
                val dmFallback = getAllNodes(rootNode).find { 
                    val cd = it.contentDescription?.toString() ?: ""
                    (cd.equals("Message", ignoreCase = true) || cd.equals("Messaging", ignoreCase = true) || cd.equals("Direct", ignoreCase = true))
                }
                
                if (dmFallback != null) {
                    Log.d("AutoFlowAccessibility", "Found dmFallback by content desc")
                    if (clickNode(dmFallback)) {
                        Log.d("AutoFlowAccessibility", "Clicked dmFallback, moving to step 2")
                        automationStep = 2
                    }
                }
            }
            2 -> {
                // We are in the inbox, need to click search.
                val searchEdit = getAllNodes(rootNode).find { it.className?.contains("EditText") == true }
                if (searchEdit != null) {
                    Log.d("AutoFlowAccessibility", "Found search EditText, clicking it")
                    if (clickNode(searchEdit)) {
                        automationStep = 3
                    }
                    return
                }
                
                // Fallback search button in Inbox
                val searchBtns = getAllNodes(rootNode).filter { 
                    (it.text?.contains("Search", ignoreCase=true) == true || it.contentDescription?.contains("Search", ignoreCase=true) == true) &&
                    it.contentDescription?.toString()?.contains("Search and explore", ignoreCase=true) != true
                }
                if (searchBtns.isNotEmpty()) {
                    Log.d("AutoFlowAccessibility", "Found search button fallback")
                    if (clickNode(searchBtns.first())) {
                        automationStep = 3
                    }
                }
            }
            3 -> {
                // Type the name in the search box
                val searchBox = getAllNodes(rootNode).find { it.className?.contains("EditText") == true }
                if (searchBox != null) {
                    Log.d("AutoFlowAccessibility", "Typing target name: $targetName")
                    val args = Bundle()
                    args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, targetName)
                    searchBox.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
                    automationStep = 4
                }
            }
            4 -> {
                // Click the user from search results
                val userNode = getAllNodes(rootNode).find { it.text?.toString()?.equals(targetName, ignoreCase=true) == true || it.contentDescription?.toString()?.equals(targetName, ignoreCase=true) == true }
                if (userNode != null) {
                    Log.d("AutoFlowAccessibility", "Found user node in search results, clicking")
                    if (clickNode(userNode)) {
                        automationStep = 5
                    }
                }
            }
            5 -> {
                // Type message in chat
                val msgBox = getAllNodes(rootNode).find { it.className?.contains("EditText") == true }
                if (msgBox != null) {
                    Log.d("AutoFlowAccessibility", "Typing message")
                    val args = Bundle()
                    args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, msg)
                    msgBox.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
                    automationStep = 6
                }
            }
            6 -> {
                // Click Send
                val sendBtn = getAllNodes(rootNode).find { it.text?.toString()?.equals("Send", ignoreCase=true) == true || it.contentDescription?.toString()?.equals("Send", ignoreCase=true) == true }
                if (sendBtn != null) {
                    Log.d("AutoFlowAccessibility", "Clicking Send button")
                    if (clickNode(sendBtn)) {
                        Log.d("AutoFlowAccessibility", "Message Sent successfully")
                        automationStep = 0
                        finishAutomation()
                    }
                } else {
                     val sendIcon = rootNode.findAccessibilityNodeInfosByViewId("com.instagram.android:id/row_thread_composer_button_send")
                     if (sendIcon.isNotEmpty()) {
                         clickNode(sendIcon[0])
                         automationStep = 0
                         finishAutomation()
                     }
                }
            }
        }
    }

    private fun handleSnapchatAutomation(rootNode: AccessibilityNodeInfo) {
        when (automationStep) {
            1 -> {
                val chatTab = getAllNodes(rootNode).find { it.contentDescription?.contains("Chat", ignoreCase = true) == true || it.text?.contains("Chat", ignoreCase = true) == true }
                if (chatTab != null) {
                    if (clickNode(chatTab)) automationStep = 2
                } else {
                    // Fallback to swipe to chats? Often snapchat has a chat button at the bottom
                    val navButtons = rootNode.findAccessibilityNodeInfosByViewId("com.snapchat.android:id/hova_header_chat_icon")
                    if (navButtons.isNotEmpty()) {
                        clickNode(navButtons[0])
                        automationStep = 2
                    }
                }
            }
            2 -> {
                val searchBtn = rootNode.findAccessibilityNodeInfosByViewId("com.snapchat.android:id/search_icon")
                if (searchBtn.isNotEmpty() && clickNode(searchBtn[0])) {
                    // do nothing wait for edittext
                }
                
                val editTexts = getAllNodes(rootNode).filter { it.className?.contains("EditText") == true }
                if (editTexts.isNotEmpty()) {
                    val arguments = Bundle().apply { putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, targetContact) }
                    editTexts[0].performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
                    automationStep = 3
                }
            }
            3 -> {
                val contactNodes = rootNode.findAccessibilityNodeInfosByText(targetContact)
                if (contactNodes.isNotEmpty()) {
                    val validContact = contactNodes.find { !(it.className?.contains("EditText") ?: false) }
                    if (validContact != null && clickNode(validContact)) {
                        automationStep = 4
                    }
                }
            }
            4 -> {
                val editTexts = getAllNodes(rootNode).filter { it.className?.contains("EditText") == true }
                if (editTexts.isNotEmpty()) {
                    val arguments = Bundle().apply { putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, messagePayload) }
                    editTexts[0].performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
                    automationStep = 5
                }
            }
            5 -> {
                val sendBtns = getAllNodes(rootNode).filter { it.text?.toString()?.equals("Send", ignoreCase=true) == true || it.contentDescription?.toString()?.equals("Send", ignoreCase=true) == true || it.contentDescription?.contains("send", ignoreCase=true) == true }
                if (sendBtns.isNotEmpty()) {
                    if (clickNode(sendBtns[0])) {
                        automationStep = 6
                        finishAutomation()
                    }
                }
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
