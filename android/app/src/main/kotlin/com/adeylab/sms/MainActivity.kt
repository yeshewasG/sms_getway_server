package com.adeylab.sms

import android.Manifest
import android.content.pm.PackageManager
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.adeylab.sms/sms"

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        val flutterEngine = flutterEngine ?: return
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSMS" -> {
                    val phone = call.argument<String>("phone")
                    val message = call.argument<String>("message")
                    if (phone != null && message != null) {
                        when {
                            phone.isEmpty() -> result.error("INVALID_PHONE", "Phone number cannot be empty", null)
                            message.isEmpty() -> result.error("INVALID_MESSAGE", "Message cannot be empty", null)
                            else -> {
                                val success = sendSMS(phone, message)
                                if (success) {
                                    result.success("SMS sent successfully")
                                } else {
                                    result.error("PERMISSION_DENIED", "SMS permission denied or sending failed", null)
                                }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "Phone or message is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun sendSMS(phone: String, message: String): Boolean {
        return try {
            if (ActivityCompat.checkSelfPermission(
                    this,
                    Manifest.permission.SEND_SMS
                ) == PackageManager.PERMISSION_GRANTED
            ) {
                val smsManager: SmsManager = SmsManager.getDefault()
                smsManager.sendTextMessage(phone, null, message, null, null)
                true
            } else {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.SEND_SMS),
                    100
                )
                false
            }
        } catch (e: Exception) {
            false
        }
    }
}