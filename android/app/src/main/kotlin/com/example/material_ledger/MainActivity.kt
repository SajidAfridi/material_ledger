package com.example.material_ledger

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Forwards a rugged device's dedicated physical action button to Flutter as the
 * app's "primary action". Many enterprise handhelds (Zebra, Sonim, CAT) expose
 * a programmable side key as KEYCODE_CAMERA or a vendor button code; map the
 * exact code for your fleet here. The Dart side listens on the
 * `material_ledger/hardware` channel (see HardwareActionService).
 *
 * Extends FlutterFragmentActivity (not FlutterActivity) because local_auth's
 * biometric prompt requires a FragmentActivity host.
 */
class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "material_ledger/hardware",
        )
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_CAMERA ||
            keyCode == KeyEvent.KEYCODE_BUTTON_R1
        ) {
            channel?.invokeMethod("primaryAction", null)
            return true
        }
        return super.onKeyDown(keyCode, event)
    }
}
