package com.credlawn.ledgeo

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.credlawn.ledgeo/contact_picker"
    private val PICK_CONTACT_REQUEST = 1001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "pickContact") {
                pendingResult = result
                pickContact()
            } else {
                result.notImplemented()
            }
        }
    }

    private fun pickContact() {
        val intent = Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI)
        startActivityForResult(intent, PICK_CONTACT_REQUEST)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_CONTACT_REQUEST && resultCode == Activity.RESULT_OK && data != null) {
            val contactUri = data.data
            if (contactUri != null) {
                val cursor: Cursor? = contentResolver.query(contactUri, null, null, null, null)
                cursor?.use {
                    if (it.moveToFirst()) {
                        val nameIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                        val phoneIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                        val name = if (nameIdx >= 0) it.getString(nameIdx) ?: "" else ""
                        val phone = if (phoneIdx >= 0) (it.getString(phoneIdx) ?: "").replace(" ", "").replace("-", "") else ""
                        pendingResult?.success(mapOf("name" to name, "phone" to phone))
                        pendingResult = null
                        return
                    }
                }
            }
        }
        pendingResult?.success(null)
        pendingResult = null
    }

    override fun onDestroy() {
        pendingResult?.success(null)
        pendingResult = null
        super.onDestroy()
    }
}
