package com.helloworld.autoflow.autoflow

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.Path
import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.content.Context
import android.os.PowerManager
import android.app.KeyguardManager

class AutoFlowAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "AutoFlowAccessibility"
        var instance: AutoFlowAccessibilityService? = null
        
        // State variables for WhatsApp automation
        var isAutomatingWhatsApp = false
        var targetContact: String? = null
        var messagePayload: String? = null
        var automationStep = 0
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d(TAG, "Accessibility Service Connected")
    }

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        Log.d(TAG, "Accessibility Service Unbound")
        return super.onUnbind(intent)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (!isAutomatingWhatsApp) return
        
        val rootNode = rootInActiveWindow ?: return

        when (automationStep) {
            1 -> {
                // Step 1: Wait for WhatsApp Home Screen, click Search icon
                val searchIcon = rootNode.findAccessibilityNodeInfosByViewId("com.whatsapp:id/menuitem_search")
                if (searchIcon.isNotEmpty()) {
                    searchIcon[0].performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    automationStep = 2
                    Log.d(TAG, "Clicked Search Icon")
                }
            }
            2 -> {
                // Step 2: Type contact name in search bar
                val searchInput = rootNode.findAccessibilityNodeInfosByViewId("com.whatsapp:id/search_src_text")
                if (searchInput.isNotEmpty()) {
                    val arguments = Bundle()
                    arguments.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, targetContact)
                    searchInput[0].performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
                    automationStep = 3
                    Log.d(TAG, "Typed contact name: $targetContact")
                }
            }
            3 -> {
                // Step 3: Click the first search result (the contact)
                // We wait a bit for results to load
                val contacts = rootNode.findAccessibilityNodeInfosByViewId("com.whatsapp:id/contactpicker_row_name")
                if (contacts.isNotEmpty()) {
                    // Check if the name matches (case insensitive)
                    for (contact in contacts) {
                        if (contact.text?.toString()?.equals(targetContact, ignoreCase = true) == true) {
                            contact.parent?.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                            automationStep = 4
                            Log.d(TAG, "Clicked Contact")
                            break
                        }
                    }
                }
            }
            4 -> {
                // Step 4: Type message in chat box
                val messageInput = rootNode.findAccessibilityNodeInfosByViewId("com.whatsapp:id/entry")
                if (messageInput.isNotEmpty()) {
                    val arguments = Bundle()
                    arguments.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, messagePayload)
                    messageInput[0].performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
                    automationStep = 5
                    Log.d(TAG, "Typed Message: $messagePayload")
                }
            }
            5 -> {
                // Step 5: Click Send button
                val sendButton = rootNode.findAccessibilityNodeInfosByViewId("com.whatsapp:id/send")
                if (sendButton.isNotEmpty()) {
                    sendButton[0].performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    
                    // Automation complete
                    isAutomatingWhatsApp = false
                    automationStep = 0
                    Log.d(TAG, "Message Sent!")
                    
                    // Return to Home screen or back
                    performGlobalAction(GLOBAL_ACTION_HOME)
                }
            }
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "Accessibility Service Interrupted")
    }

    // Method to trigger automation from external components (like MainActivity or Workmanager)
    fun startWhatsAppAutomation(contact: String, message: String) {
        targetContact = contact
        messagePayload = message
        isAutomatingWhatsApp = true
        automationStep = 1
        
        wakeUpDevice()

        Log.d(TAG, "Starting WhatsApp Automation for $contact")
        
        // Launch WhatsApp
        val launchIntent = packageManager.getLaunchIntentForPackage("com.whatsapp")
        if (launchIntent != null) {
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(launchIntent)
        } else {
            Log.e(TAG, "WhatsApp not installed")
            isAutomatingWhatsApp = false
        }
    }
    
    @Suppress("DEPRECATION")
    private fun wakeUpDevice() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
            "AutoFlow::WakeLock"
        )
        wakeLock.acquire(10000) // Keep awake for 10 seconds

        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val keyguardLock = keyguardManager.newKeyguardLock("AutoFlow::Keyguard")
        keyguardLock.disableKeyguard()
    }
}
