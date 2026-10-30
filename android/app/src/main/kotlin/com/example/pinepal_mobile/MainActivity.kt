package com.example.pinepal_mobile

import android.os.Build
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // Android draws a yellow-green outline around a view that has keyboard focus,
    // for example after pressing Tab on a computer keyboard in the emulator. The
    // app has its own focus styles, so the system outline is switched off.
    override fun onPostResume() {
        super.onPostResume()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            hideFocusHighlight(window.decorView)
        }
    }

    private fun hideFocusHighlight(view: View) {
        view.defaultFocusHighlightEnabled = false
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                hideFocusHighlight(view.getChildAt(i))
            }
        }
    }
}
