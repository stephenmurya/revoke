package com.crescence.revoke

import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import android.text.TextUtils

object AccessibilityPermissionUtils {
    fun isAccessibilityServiceEnabled(context: Context): Boolean {
        val expectedComponentName = ComponentName(context, RevokeAccessibilityService::class.java)
        val enabledServicesSetting =
            Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            ) ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServicesSetting)

        while (colonSplitter.hasNext()) {
            val componentNameString = colonSplitter.next()
            val enabledService = ComponentName.unflattenFromString(componentNameString)
            if (enabledService == expectedComponentName) {
                return true
            }
        }

        return false
    }

    fun isFastPathActive(context: Context): Boolean {
        return isAccessibilityServiceEnabled(context) && RevokeAccessibilityService.isRunning()
    }
}
