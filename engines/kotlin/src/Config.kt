package app.main

import android.content.Context
import androidx.compose.ui.graphics.Color
import org.json.JSONArray
import org.json.JSONObject

/** The app's design made in Alpha (res/raw/alpha_config.json, written by factory/prepare.py). */
data class ColumnCfg(
    val name: String,
    val label: String,
    val type: String,
    val required: Boolean,
    val options: List<String>,
    val default: String?,
    val show: Boolean,
    val adminOnly: Boolean,
)

data class TableCfg(
    val name: String,
    val label: String,
    val icon: String,
    val owner: String,
    val columns: List<ColumnCfg>,
    val notifyOnInsert: String,
    val notifyOnUpdate: String,
) {
    val hasOwner get() = owner == "customer" || owner == "public"
    val titleColumn get() = columns.firstOrNull { it.type == "text" || it.type == "choice" } ?: columns.firstOrNull()
    val imageColumn get() = columns.firstOrNull { it.type == "image" }
    val badgeColumn get() = columns.firstOrNull { it.type == "choice" && it.adminOnly } ?: columns.firstOrNull { it.type == "choice" }
    val priceColumn get() = columns.firstOrNull { it.type == "decimal" }
    fun canAdd(admin: Boolean) = admin || owner == "customer" || owner == "public"
    fun canEdit(admin: Boolean, mine: Boolean) = admin || ((owner == "customer" || owner == "public") && mine)
}

class AlphaConfig(val json: JSONObject) {
    private val app = json.optJSONObject("app") ?: JSONObject()
    private val theme = json.optJSONObject("theme") ?: JSONObject()
    val backend: JSONObject = json.optJSONObject("backend") ?: JSONObject()

    val title: String = app.optString("title", "Alpha")
    val slug: String = app.optString("slug", "app")
    val role: String = app.optString("role", "single")
    val rtl: Boolean = app.optBoolean("rtl", true)
    val headline: String = app.optString("headline", "")
    val subtitle: String = app.optString("subtitle", "")

    val backendType: String = backend.optString("type", "none")
    val prefix: String = backend.optString("prefix", slug.replace("-", "_"))
    val auth: String = backend.optString("auth", "none")
    val needsAccount: Boolean = auth == "email_password" || auth == "email_code"

    /** Sign-up is confirmed with a 6-digit code sent to the email. */
    val emailCode: Boolean = auth == "email_code"
    val push: Boolean = backend.optBoolean("push", false)

    val seed: Color = parseColor(theme.optString("seed", "#6E4BFF"), Color(0xFF6E4BFF))
    val accent: Color = parseColor(theme.optString("accent", "#2DD4BF"), Color(0xFF2DD4BF))
    val mode: String = theme.optString("mode", "dark")
    val style: String = theme.optString("style", "glass")
    val radius: Float = theme.optDouble("radius", 18.0).toFloat()

    val tables: List<TableCfg> = (json.optJSONArray("tables") ?: JSONArray()).let { arr ->
        (0 until arr.length()).map { i -> parseTable(arr.getJSONObject(i)) }
    }

    fun visibleTables(admin: Boolean) = tables.filter { it.owner != "admin" || admin || role == "admin" }

    companion object {
        fun load(context: Context): AlphaConfig {
            val text = context.resources.openRawResource(R.raw.alpha_config).bufferedReader(Charsets.UTF_8).use { it.readText() }
            return AlphaConfig(JSONObject(text))
        }

        private fun parseTable(o: JSONObject): TableCfg {
            val cols = o.optJSONArray("columns") ?: JSONArray()
            val notify = o.optJSONObject("notify") ?: JSONObject()
            return TableCfg(
                name = o.getString("name"),
                label = o.optString("label", o.getString("name")),
                icon = o.optString("icon", "list"),
                owner = o.optString("owner", "customer"),
                columns = (0 until cols.length()).map { i ->
                    val c = cols.getJSONObject(i)
                    val opts = c.optJSONArray("options") ?: JSONArray()
                    ColumnCfg(
                        name = c.getString("name"),
                        label = c.optString("label", c.getString("name")),
                        type = c.optString("type", "text"),
                        required = c.optBoolean("required", false),
                        options = (0 until opts.length()).map { opts.getString(it) },
                        default = if (c.has("default") && !c.isNull("default")) c.get("default").toString() else null,
                        show = c.optBoolean("show", true),
                        adminOnly = c.optBoolean("adminOnly", false),
                    )
                },
                notifyOnInsert = notify.optString("onInsert", "none"),
                notifyOnUpdate = notify.optString("onUpdate", "none"),
            )
        }

        fun parseColor(hex: String, fallback: Color): Color = try {
            val h = hex.removePrefix("#")
            Color(("FF" + h).toLong(16).toInt())
        } catch (e: Exception) {
            fallback
        }
    }
}
