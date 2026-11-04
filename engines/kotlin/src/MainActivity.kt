package app.main

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection

/** Made with Alpha. Screens, data and rules come from res/raw/alpha_config.json (the design in Alpha). */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val config = AlphaConfig.load(this)
        val backend = Backend.create(config, this)
        setContent {
            CompositionLocalProvider(LocalLayoutDirection provides if (config.rtl) LayoutDirection.Rtl else LayoutDirection.Ltr) {
                AppTheme(config) {
                    AlphaApp(backend) { Push.setup(this, backend) }
                }
            }
        }
    }
}
