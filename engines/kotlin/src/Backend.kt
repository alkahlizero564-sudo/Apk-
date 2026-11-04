package app.main

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.time.Instant
import java.time.LocalDate
import java.time.OffsetDateTime
import java.util.UUID
import java.util.concurrent.TimeUnit

typealias Rec = Map<String, Any?>

const val EMAIL_NOT_CONFIRMED = "EMAIL_NOT_CONFIRMED"

class BackendException(message: String) : Exception(message)

/** Sign-in refused because the email is not confirmed yet: the app shows the code screen. */
class NeedsConfirmation(val address: String) : Exception("أكّد بريدك أولاً بالرمز الذي وصلك.")

data class AppNotification(val id: String, val title: String, val body: String, val at: Instant, val read: Boolean)

/** Data of the app: on the phone or on Supabase. Same API in every Alpha engine. */
abstract class Backend(val config: AlphaConfig, context: Context) {
    protected val prefs: SharedPreferences = context.getSharedPreferences("alpha", Context.MODE_PRIVATE)
    var signedIn = false
        protected set
    var isAdmin = false
        protected set
    var userId: String? = null
        protected set
    var email: String? = null
        protected set
    var name: String? = null
        protected set

    abstract val kind: String
    abstract suspend fun init()
    abstract suspend fun signIn(email: String, password: String)
    /** Makes the account; true when the email must be confirmed with a code first. */
    abstract suspend fun signUp(name: String, phone: String, email: String, password: String): Boolean
    open suspend fun verifyCode(email: String, code: String, password: String) {}
    open suspend fun resendCode(email: String) {}
    abstract suspend fun signOut()
    abstract suspend fun list(table: TableCfg): List<Rec>
    abstract suspend fun insert(table: TableCfg, values: Rec): Rec
    abstract suspend fun update(table: TableCfg, id: String, values: Rec)
    abstract suspend fun delete(table: TableCfg, id: String)
    abstract suspend fun notifications(): List<AppNotification>
    abstract suspend fun notify(toRole: String, title: String, body: String, toUser: String? = null)
    abstract suspend fun stats(): Map<String, Int>
    abstract suspend fun registerDevice(token: String)

    fun isMine(row: Rec): Boolean = row["customer_id"] == null || row["customer_id"] == userId

    fun markSeen() = prefs.edit().putString("alpha_seen", Instant.now().toString()).apply()

    protected fun seenAt(): Instant = prefs.getString("alpha_seen", null)?.let { parseInstant(it) } ?: Instant.EPOCH

    /** Values ready to save: empty fields removed, numbers typed, admin-only fields kept for admins only. */
    fun clean(table: TableCfg, values: Rec): Map<String, Any?> {
        val out = linkedMapOf<String, Any?>()
        for (c in table.columns) {
            if (!values.containsKey(c.name)) continue
            if (c.adminOnly && !isAdmin) continue
            var v = values[c.name]
            if (v is String) {
                val s = v.trim()
                v = when {
                    s.isEmpty() -> null
                    c.type == "int" -> s.replace(",", "").toLongOrNull() ?: s
                    c.type == "decimal" -> s.replace(",", "").toDoubleOrNull() ?: s
                    else -> s
                }
            }
            out[c.name] = v
        }
        return out
    }

    fun defaults(table: TableCfg): Map<String, Any?> {
        val out = linkedMapOf<String, Any?>()
        for (c in table.columns) {
            val d = c.default ?: continue
            if (d.isEmpty() || (c.adminOnly && !isAdmin)) continue
            out[c.name] = when (c.type) {
                "int" -> d.toLongOrNull()
                "decimal" -> d.toDoubleOrNull()
                "bool" -> d == "true"
                "date" -> if (d == "today" || d == "now") LocalDate.now().toString() else d
                "datetime" -> if (d == "now") Instant.now().toString() else d
                else -> d
            }
        }
        return out
    }

    companion object {
        fun create(config: AlphaConfig, context: Context): Backend =
            if (config.backendType == "supabase") SupabaseBackend(config, context) else LocalBackend(config, context)
    }
}

fun parseInstant(value: String?): Instant {
    if (value.isNullOrEmpty()) return Instant.now()
    return runCatching { OffsetDateTime.parse(value.replace(" ", "T")).toInstant() }
        .recoverCatching { Instant.parse(value) }
        .getOrDefault(Instant.now())
}

fun JSONObject.toRec(): Rec = keys().asSequence().associateWith { k -> if (isNull(k)) null else get(k) }

fun Rec.toJson(): JSONObject = JSONObject().also { o -> forEach { (k, v) -> o.put(k, v ?: JSONObject.NULL) } }

class LocalBackend(config: AlphaConfig, context: Context) : Backend(config, context) {
    override val kind = "none"

    private fun rows(t: TableCfg): MutableList<Rec> {
        val arr = JSONArray(prefs.getString("rows_${t.name}", "[]"))
        return (0 until arr.length()).map { arr.getJSONObject(it).toRec() }.toMutableList()
    }

    private fun save(t: TableCfg, rows: List<Rec>) {
        val arr = JSONArray()
        rows.forEach { arr.put(it.toJson()) }
        prefs.edit().putString("rows_${t.name}", arr.toString()).apply()
    }

    override suspend fun init() {
        if (prefs.getString("alpha_uid", null) == null) prefs.edit().putString("alpha_uid", UUID.randomUUID().toString()).apply()
        userId = prefs.getString("alpha_uid", null)
        name = prefs.getString("alpha_name", null)
        signedIn = true
        isAdmin = true
    }

    override suspend fun signIn(email: String, password: String) {}
    override suspend fun signUp(name: String, phone: String, email: String, password: String): Boolean {
        prefs.edit().putString("alpha_name", name).apply()
        return false
    }
    override suspend fun signOut() {}

    override suspend fun list(table: TableCfg): List<Rec> = rows(table).sortedByDescending { it["created_at"]?.toString() ?: "" }

    override suspend fun insert(table: TableCfg, values: Rec): Rec {
        val now = Instant.now().toString()
        val row = defaults(table) + clean(table, values) +
            mapOf("id" to UUID.randomUUID().toString(), "created_at" to now, "updated_at" to now, "customer_id" to userId)
        save(table, rows(table) + row)
        return row
    }

    override suspend fun update(table: TableCfg, id: String, values: Rec) {
        save(table, rows(table).map { if (it["id"] == id) it + clean(table, values) + ("updated_at" to Instant.now().toString()) else it })
    }

    override suspend fun delete(table: TableCfg, id: String) = save(table, rows(table).filter { it["id"] != id })
    override suspend fun notifications(): List<AppNotification> = emptyList()
    override suspend fun notify(toRole: String, title: String, body: String, toUser: String?) {}
    override suspend fun stats(): Map<String, Int> = config.tables.associate { it.name to rows(it).size }
    override suspend fun registerDevice(token: String) {}
}

class SupabaseBackend(config: AlphaConfig, context: Context) : Backend(config, context) {
    override val kind = "supabase"
    private val url = config.backend.optString("url", "").trimEnd('/')
    private val key = config.backend.optString("anonKey", "")
    private val http = OkHttpClient.Builder().callTimeout(30, TimeUnit.SECONDS).build()
    private val jsonType = "application/json".toMediaType()
    private var session: JSONObject? = null

    private fun explain(code: Int, body: String): String {
        val msg = runCatching {
            val j = JSONObject(body)
            listOf("msg", "message", "error_description", "error").firstNotNullOfOrNull { k -> j.optString(k).ifEmpty { null } } ?: body
        }.getOrDefault(body)
        val m = msg.lowercase()
        return when {
            "email not confirmed" in m -> EMAIL_NOT_CONFIRMED
            "invalid login" in m -> "البريد أو كلمة المرور غير صحيحة."
            "already registered" in m || "already been registered" in m -> "هذا البريد مسجّل من قبل، سجّل الدخول."
            "password should be" in m -> "كلمة المرور قصيرة (6 أحرف على الأقل)."
            "row-level security" in m || code == 403 -> "ليست لديك صلاحية لهذه العملية."
            else -> "خطأ من السيرفر ($code): $msg"
        }
    }

    private suspend fun call(method: String, path: String, body: Any? = null, prefer: String? = null, refresh: Boolean = true): String =
        withContext(Dispatchers.IO) {
            if (refresh) refreshIfNeeded(false)
            val token = session?.optString("access_token")?.ifEmpty { null } ?: key
            val reqBody = when (body) {
                null -> if (method == "GET" || method == "DELETE") null else "{}".toRequestBody(jsonType)
                is JSONObject -> body.toString().toRequestBody(jsonType)
                else -> body.toString().toRequestBody(jsonType)
            }
            val builder = Request.Builder().url(url + path).method(method, reqBody)
                .header("apikey", key).header("Authorization", "Bearer $token").header("Content-Type", "application/json")
            if (prefer != null) builder.header("Prefer", prefer)
            try {
                http.newCall(builder.build()).execute().use { res ->
                    val text = res.body?.string() ?: ""
                    if (!res.isSuccessful) throw BackendException(explain(res.code, text))
                    text
                }
            } catch (e: IOException) {
                throw BackendException("لا يوجد اتصال بالإنترنت.")
            }
        }

    private fun saveSession(s: JSONObject) {
        s.put("expires_at_ms", System.currentTimeMillis() + s.optLong("expires_in", 3600) * 1000)
        session = s
        prefs.edit().putString("alpha_session", s.toString()).apply()
        val user = s.optJSONObject("user")
        signedIn = true
        userId = user?.optString("id")
        email = user?.optString("email")?.ifEmpty { null }
    }

    private suspend fun refreshIfNeeded(force: Boolean) {
        val s = session ?: return
        if (!force && s.optLong("expires_at_ms") - System.currentTimeMillis() > 60_000) return
        val body = JSONObject().put("refresh_token", s.optString("refresh_token"))
        saveSession(JSONObject(call("POST", "/auth/v1/token?grant_type=refresh_token", body, refresh = false)))
    }

    private suspend fun anonymous() = saveSession(JSONObject(call("POST", "/auth/v1/signup", JSONObject(), refresh = false)))

    private suspend fun loadProfile() {
        var role = "customer"
        try {
            val arr = JSONArray(call("GET", "/rest/v1/${config.prefix}_profiles?select=role,full_name&id=eq.$userId"))
            if (arr.length() > 0) {
                role = arr.getJSONObject(0).optString("role", "customer")
                name = arr.getJSONObject(0).optString("full_name").ifEmpty { null }
            }
        } catch (e: BackendException) {
            role = "customer"
        }
        isAdmin = config.role != "customer" && role == "admin"
    }

    override suspend fun init() {
        if (url.isEmpty() || key.isEmpty()) throw BackendException("السيرفر لم يُجهّز بعد. افتح Alpha واضغط «تجهيز السيرفر» ثم ابنِ التطبيق مرة أخرى.")
        prefs.getString("alpha_session", null)?.let {
            try {
                saveSession(JSONObject(it))
                refreshIfNeeded(true)
            } catch (e: Exception) {
                session = null
                signedIn = false
                prefs.edit().remove("alpha_session").apply()
            }
        }
        if (session == null && !config.needsAccount) anonymous()
        if (session != null) loadProfile()
    }

    override suspend fun signIn(email: String, password: String) {
        val body = JSONObject().put("email", email.trim()).put("password", password)
        try {
            saveSession(JSONObject(call("POST", "/auth/v1/token?grant_type=password", body, refresh = false)))
        } catch (e: BackendException) {
            if (e.message == EMAIL_NOT_CONFIRMED) throw NeedsConfirmation(email.trim())
            throw e
        }
        loadProfile()
    }

    override suspend fun signUp(name: String, phone: String, email: String, password: String): Boolean {
        val body = JSONObject().put("email", email.trim()).put("password", password)
            .put("data", JSONObject().put("full_name", name.trim()).put("phone", phone.trim()))
        val s = JSONObject(call("POST", "/auth/v1/signup", body, refresh = false))
        if (!s.has("access_token")) {
            if (config.emailCode) return true
            signIn(email, password)
            return false
        }
        saveSession(s)
        loadProfile()
        return false
    }

    override suspend fun verifyCode(email: String, code: String, password: String) {
        val body = JSONObject().put("type", "signup").put("email", email.trim()).put("token", code.trim())
        val s = try {
            JSONObject(call("POST", "/auth/v1/verify", body, refresh = false))
        } catch (e: BackendException) {
            throw BackendException("الرمز غير صحيح أو انتهت صلاحيته. اطلب رمزاً جديداً.")
        }
        if (s.has("access_token")) {
            saveSession(s)
            loadProfile()
        } else {
            signIn(email, password)
        }
    }

    override suspend fun resendCode(email: String) {
        call("POST", "/auth/v1/resend", JSONObject().put("type", "signup").put("email", email.trim()), refresh = false)
    }

    override suspend fun signOut() {
        runCatching { call("POST", "/auth/v1/logout", JSONObject()) }
        session = null
        prefs.edit().remove("alpha_session").apply()
        signedIn = false
        isAdmin = false
        userId = null
        email = null
        if (!config.needsAccount) {
            anonymous()
            loadProfile()
        }
    }

    private fun t(table: TableCfg) = "${config.prefix}_${table.name}"

    private fun rowsOf(text: String): List<Rec> {
        val arr = JSONArray(text)
        return (0 until arr.length()).map { arr.getJSONObject(it).toRec() }
    }

    override suspend fun list(table: TableCfg): List<Rec> {
        var q = "/rest/v1/${t(table)}?select=*&order=created_at.desc&limit=500"
        if (table.owner == "customer" && !isAdmin) q += "&customer_id=eq.$userId"
        return rowsOf(call("GET", q))
    }

    override suspend fun insert(table: TableCfg, values: Rec): Rec =
        rowsOf(call("POST", "/rest/v1/${t(table)}", clean(table, values).toJson(), prefer = "return=representation")).firstOrNull() ?: emptyMap()

    override suspend fun update(table: TableCfg, id: String, values: Rec) {
        call("PATCH", "/rest/v1/${t(table)}?id=eq.$id", clean(table, values).toJson(), prefer = "return=minimal")
    }

    override suspend fun delete(table: TableCfg, id: String) {
        call("DELETE", "/rest/v1/${t(table)}?id=eq.$id")
    }

    override suspend fun notifications(): List<AppNotification> {
        val uid = userId ?: return emptyList()
        val roles = when (config.role) {
            "customer" -> listOf("customer")
            "admin" -> listOf("admin")
            else -> listOf("customer") + if (isAdmin) listOf("admin") else emptyList()
        }
        val or = (listOf("to_user.eq.$uid") + roles.map { "to_role.eq.$it" }).joinToString(",")
        val seen = seenAt()
        return rowsOf(call("GET", "/rest/v1/${config.prefix}_notifications?select=*&or=($or)&order=created_at.desc&limit=60")).map {
            val at = parseInstant(it["created_at"]?.toString())
            AppNotification(it["id"].toString(), it["title"]?.toString() ?: "", it["body"]?.toString() ?: "", at, !at.isAfter(seen))
        }
    }

    override suspend fun notify(toRole: String, title: String, body: String, toUser: String?) {
        val o = JSONObject().put("title", title).put("body", body).put("created_by", userId)
        if (toUser != null) o.put("to_user", toUser) else o.put("to_role", toRole)
        call("POST", "/rest/v1/${config.prefix}_notifications", o, prefer = "return=minimal")
    }

    override suspend fun stats(): Map<String, Int> {
        val o = JSONObject(call("POST", "/rest/v1/rpc/${config.prefix}_stats", JSONObject()))
        return o.keys().asSequence().associateWith { o.optInt(it) }
    }

    override suspend fun registerDevice(token: String) {
        val o = JSONObject().put("device_token", token).put("app_name", config.role).put("device_platform", "android")
        runCatching { call("POST", "/rest/v1/rpc/${config.prefix}_register_device", o) }
    }
}
