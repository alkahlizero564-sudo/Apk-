package app.main

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Logout
import androidx.compose.material.icons.automirrored.rounded.ReceiptLong
import androidx.compose.material.icons.automirrored.rounded.MenuBook
import androidx.compose.material.icons.automirrored.rounded.ViewList
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.rounded.AccountBalanceWallet
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.Campaign
import androidx.compose.material.icons.rounded.ChatBubble
import androidx.compose.material.icons.rounded.Checklist
import androidx.compose.material.icons.rounded.CloudOff
import androidx.compose.material.icons.rounded.Dashboard
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.DeliveryDining
import androidx.compose.material.icons.rounded.DirectionsCar
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.EventAvailable
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.MedicalServices
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material.icons.rounded.Payments
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Phone
import androidx.compose.material.icons.rounded.Photo
import androidx.compose.material.icons.rounded.Place
import androidx.compose.material.icons.rounded.Restaurant
import androidx.compose.material.icons.rounded.School
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.ShoppingBag
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.Storefront
import androidx.compose.material.icons.rounded.Work
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

fun iconFor(name: String): ImageVector = when (name) {
    "shopping_bag" -> Icons.Rounded.ShoppingBag
    "receipt" -> Icons.AutoMirrored.Rounded.ReceiptLong
    "star" -> Icons.Rounded.Star
    "restaurant" -> Icons.Rounded.Restaurant
    "delivery" -> Icons.Rounded.DeliveryDining
    "medical" -> Icons.Rounded.MedicalServices
    "calendar" -> Icons.Rounded.CalendarMonth
    "event" -> Icons.Rounded.EventAvailable
    "place" -> Icons.Rounded.Place
    "school" -> Icons.Rounded.School
    "campaign" -> Icons.Rounded.Campaign
    "book" -> Icons.AutoMirrored.Rounded.MenuBook
    "chat" -> Icons.Rounded.ChatBubble
    "person" -> Icons.Rounded.Person
    "wallet" -> Icons.Rounded.AccountBalanceWallet
    "checklist" -> Icons.Rounded.Checklist
    "home" -> Icons.Rounded.Home
    "settings" -> Icons.Rounded.Settings
    "car" -> Icons.Rounded.DirectionsCar
    "phone" -> Icons.Rounded.Phone
    "photo" -> Icons.Rounded.Photo
    "store" -> Icons.Rounded.Storefront
    "work" -> Icons.Rounded.Work
    "payments" -> Icons.Rounded.Payments
    else -> Icons.AutoMirrored.Rounded.ViewList
}

fun fmt(c: ColumnCfg, v: Any?): String {
    if (v == null || v == JSONNull || v.toString().isEmpty()) return ""
    return when (c.type) {
        "bool" -> if (v == true || v.toString() == "true") "نعم" else "لا"
        "decimal" -> v.toString().toDoubleOrNull()?.let { if (it == Math.floor(it)) it.toLong().toString() else String.format(java.util.Locale.US, "%.2f", it) } ?: v.toString()
        "datetime" -> runCatching {
            DateTimeFormatter.ofPattern("yyyy/MM/dd  HH:mm").withZone(ZoneId.systemDefault()).format(parseInstant(v.toString()))
        }.getOrDefault(v.toString())
        "date" -> v.toString().take(10).replace("-", "/")
        else -> v.toString()
    }
}

private val JSONNull = org.json.JSONObject.NULL

/** Card border of the look chosen in Alpha: thick and black for the bold look, a thin frame for outline. */
fun lookBorder(config: AlphaConfig): BorderStroke? = when (config.style) {
    "brutal" -> BorderStroke(2.5.dp, Color(0xFF0B0B0F))
    "outline" -> BorderStroke(1.5.dp, config.seed.copy(alpha = 0.45f))
    else -> null
}

@Composable
fun AppTheme(config: AlphaConfig, content: @Composable () -> Unit) {
    val dark = when (config.mode) {
        "light" -> false
        "system" -> isSystemInDarkTheme()
        else -> true
    }
    val scheme = if (dark) {
        darkColorScheme(primary = config.seed, secondary = config.accent, background = Color(0xFF0B0D16), surface = Color(0xFF12141F),
            surfaceVariant = Color(0xFF1B1E2C))
    } else {
        lightColorScheme(primary = config.seed, secondary = config.accent, background = Color(0xFFF5F6FB), surface = Color.White,
            surfaceVariant = Color(0xFFEEF0F7))
    }
    MaterialTheme(colorScheme = scheme, content = content)
}

private fun brand(config: AlphaConfig) = Brush.linearGradient(listOf(config.seed, config.accent))

@Composable
fun AlphaApp(backend: Backend, onSignedIn: () -> Unit) {
    val config = backend.config
    val scope = rememberCoroutineScope()
    var ready by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var version by remember { mutableIntStateOf(0) }

    fun start() {
        error = null
        ready = false
        scope.launch {
            try {
                backend.init()
                ready = true
                if (backend.signedIn) onSignedIn()
            } catch (e: Exception) {
                error = e.message ?: e.toString()
            }
        }
    }
    LaunchedEffect(Unit) { start() }

    Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        when {
            error != null -> Empty(Icons.Rounded.CloudOff, error!!) { Button(onClick = { start() }) { Text("إعادة المحاولة") } }
            !ready -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            !backend.signedIn -> Login(backend) {
                version++
                onSignedIn()
            }
            config.role == "admin" && !backend.isAdmin -> Empty(Icons.Rounded.Lock, "الحساب ${backend.email ?: ""} ليس مديراً.\nأضف بريده كمدير في Alpha.") {
                Button(onClick = { scope.launch { backend.signOut(); version++ } }) { Text("تسجيل الخروج") }
            }
            else -> {
                MainScreen(backend, version) { version++ }
                UpdateDialog(config)
            }
        }
    }
}

@Composable
fun Empty(icon: ImageVector, text: String, action: (@Composable () -> Unit)? = null) {
    Column(Modifier.fillMaxSize().padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
        Box(Modifier.size(88.dp).clip(CircleShape).background(MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)), contentAlignment = Alignment.Center) {
            Icon(icon, null, Modifier.size(42.dp), tint = MaterialTheme.colorScheme.primary)
        }
        Spacer(Modifier.height(16.dp))
        Text(text, color = MaterialTheme.colorScheme.onSurfaceVariant, lineHeight = 24.sp)
        if (action != null) {
            Spacer(Modifier.height(16.dp))
            action()
        }
    }
}

@Composable
fun Login(backend: Backend, onDone: () -> Unit) {
    val config = backend.config
    val scope = rememberCoroutineScope()
    // login | signup | code
    var mode by remember { mutableStateOf("login") }
    var name by remember { mutableStateOf("") }
    var phone by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var pass by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var info by remember { mutableStateOf<String?>(null) }
    val shape = RoundedCornerShape(config.radius.dp)

    fun submit() {
        message = null
        when (mode) {
            "code" -> if (!Regex("^\\d{6}$").matches(code.trim())) { message = "اكتب الرمز من 6 أرقام"; return }
            else -> {
                if (!email.contains("@") || pass.length < 6) { message = "اكتب بريداً صحيحاً وكلمة مرور من 6 أحرف"; return }
                if (mode == "signup" && (name.trim().length < 2 || !Regex("^[+0-9 ()-]{7,20}$").matches(phone.trim()))) {
                    message = "اكتب الاسم ورقم هاتف صحيح"; return
                }
            }
        }
        busy = true
        scope.launch {
            try {
                when (mode) {
                    "signup" -> if (backend.signUp(name, phone, email, pass)) {
                        mode = "code"
                        info = "أرسلنا رمز التأكيد إلى بريدك"
                    } else onDone()
                    "code" -> { backend.verifyCode(email, code, pass); onDone() }
                    else -> { backend.signIn(email, pass); onDone() }
                }
            } catch (e: NeedsConfirmation) {
                mode = "code"
                info = "أكّد بريدك أولاً: أدخل الرمز الذي وصلك، أو اطلب رمزاً جديداً"
            } catch (e: Exception) {
                message = e.message
            } finally {
                busy = false
            }
        }
    }

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        Box(Modifier.fillMaxWidth().height(260.dp).background(brand(config)), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(if (config.role == "admin") Icons.Rounded.Lock else Icons.Rounded.Person, null, Modifier.size(48.dp), tint = Color.White)
                Spacer(Modifier.height(10.dp))
                Text(config.title, color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Black)
                Text(
                    when (mode) { "code" -> "تأكيد البريد الإلكتروني"; "signup" -> "أنشئ حسابك"; else -> if (config.role == "admin") "لوحة الإدارة" else "مرحباً بعودتك" },
                    color = Color.White.copy(alpha = 0.85f),
                )
            }
        }
        Card(Modifier.padding(18.dp).fillMaxWidth(), shape = shape) {
            Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                if (mode == "code") {
                    Text("أدخل الرمز المكوّن من 6 أرقام الذي أرسلناه إلى ${email.trim()}", lineHeight = 22.sp)
                    OutlinedTextField(code, { code = it.filter(Char::isDigit).take(6) }, label = { Text("الرمز") }, singleLine = true, shape = shape,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), modifier = Modifier.fillMaxWidth())
                } else {
                    if (mode == "signup") {
                        OutlinedTextField(name, { name = it }, label = { Text("الاسم") }, singleLine = true, shape = shape, modifier = Modifier.fillMaxWidth())
                        OutlinedTextField(phone, { phone = it }, label = { Text("رقم الهاتف") }, singleLine = true, shape = shape,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone), modifier = Modifier.fillMaxWidth())
                    }
                    OutlinedTextField(email, { email = it }, label = { Text("البريد الإلكتروني") }, singleLine = true, shape = shape,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email), modifier = Modifier.fillMaxWidth())
                    OutlinedTextField(pass, { pass = it }, label = { Text("كلمة المرور") }, singleLine = true, shape = shape,
                        visualTransformation = PasswordVisualTransformation(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password), modifier = Modifier.fillMaxWidth())
                }
                info?.let { Text(it, color = MaterialTheme.colorScheme.primary) }
                message?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                Button(onClick = { submit() }, enabled = !busy, shape = shape, modifier = Modifier.fillMaxWidth().height(52.dp)) {
                    Text(when (mode) { "code" -> "تأكيد"; "signup" -> "إنشاء الحساب"; else -> "دخول" }, fontWeight = FontWeight.Bold)
                }
                if (mode == "code") {
                    TextButton(onClick = {
                        scope.launch {
                            try { backend.resendCode(email); info = "أُرسل الرمز من جديد" } catch (e: Exception) { message = e.message }
                        }
                    }, modifier = Modifier.fillMaxWidth()) { Text("أرسل الرمز مرة أخرى") }
                    TextButton(onClick = { mode = "login" }, modifier = Modifier.fillMaxWidth()) { Text("رجوع لتسجيل الدخول") }
                } else {
                    TextButton(onClick = { mode = if (mode == "signup") "login" else "signup" }, modifier = Modifier.fillMaxWidth()) {
                        Text(if (mode == "signup") "عندي حساب، سجّل دخولي" else "ما عندي حساب؟ أنشئ واحداً")
                    }
                }
            }
        }
    }
}

private data class Tab(val label: String, val icon: ImageVector, val kind: String, val table: TableCfg? = null)

@Composable
fun MainScreen(backend: Backend, version: Int, onSignedOut: () -> Unit) {
    val config = backend.config
    val scope = rememberCoroutineScope()
    val snackbar = remember { SnackbarHostState() }
    var tab by remember { mutableIntStateOf(0) }
    var unread by remember { mutableIntStateOf(0) }
    var adding by remember { mutableStateOf<TableCfg?>(null) }
    var refresh by remember { mutableIntStateOf(0) }
    var composing by remember { mutableStateOf(false) }

    val tables = config.visibleTables(backend.isAdmin)
    val tabs = buildList {
        add(Tab("الرئيسية", Icons.Rounded.Dashboard, "home"))
        tables.take(3).forEach { add(Tab(it.label, iconFor(it.icon), "table", it)) }
        if (backend.kind != "none") add(Tab("الإشعارات", Icons.Rounded.Notifications, "notes"))
        add(Tab("حسابي", Icons.Rounded.Person, "me"))
    }
    if (tab >= tabs.size) tab = 0
    val current = tabs[tab]
    fun toast(text: String) {
        scope.launch { snackbar.showSnackbar(text) }
    }

    LaunchedEffect(version) {
        while (backend.kind != "none") {
            runCatching { unread = backend.notifications().count { !it.read } }
            delay(30_000)
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = { if (current.kind != "home") CenterAlignedTopAppBar(title = { Text(current.label, fontWeight = FontWeight.ExtraBold) }) },
        floatingActionButton = {
            when {
                current.kind == "table" && current.table!!.canAdd(backend.isAdmin) ->
                    ExtendedFloatingActionButton(onClick = { adding = current.table }, icon = { Icon(Icons.Rounded.Add, null) }, text = { Text("إضافة") })
                current.kind == "notes" -> FloatingActionButton(onClick = { composing = true }) { Icon(Icons.AutoMirrored.Rounded.Send, null) }
            }
        },
        bottomBar = {
            NavigationBar {
                tabs.forEachIndexed { i, t ->
                    NavigationBarItem(
                        selected = i == tab,
                        onClick = { tab = i },
                        icon = {
                            if (t.kind == "notes" && unread > 0) BadgedBox(badge = { Badge { Text("$unread") } }) { Icon(t.icon, null) }
                            else Icon(t.icon, null)
                        },
                        label = { Text(t.label, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                    )
                }
            }
        },
    ) { inner ->
        Box(Modifier.padding(inner).fillMaxSize()) {
            when (current.kind) {
                "home" -> Home(backend) { i -> tab = (i + 1).coerceAtMost(tabs.size - 1) }
                "table" -> TableScreen(backend, current.table!!, refresh, ::toast)
                "notes" -> Notes(backend, refresh) { unread = 0 }
                else -> Me(backend) { scope.launch { backend.signOut(); onSignedOut() } }
            }
        }
    }

    adding?.let { t ->
        RowForm(backend, t, null, onDismiss = { adding = null }) {
            adding = null
            refresh++
            toast("تمت الإضافة ✓")
        }
    }
    if (composing) {
        var title by remember { mutableStateOf("") }
        var body by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { composing = false },
            title = { Text(if (backend.isAdmin) "إشعار لكل العملاء" else "رسالة للإدارة") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    OutlinedTextField(title, { title = it }, label = { Text("العنوان") })
                    OutlinedTextField(body, { body = it }, label = { Text("النص") }, minLines = 2)
                }
            },
            confirmButton = {
                Button(onClick = {
                    if (title.isBlank()) return@Button
                    scope.launch {
                        try {
                            backend.notify(if (backend.isAdmin) "customer" else "admin", title.trim(), body.trim())
                            composing = false
                            refresh++
                            toast("تم الإرسال ✓")
                        } catch (e: Exception) {
                            toast(e.message ?: "خطأ")
                        }
                    }
                }) { Text("إرسال") }
            },
            dismissButton = { TextButton(onClick = { composing = false }) { Text("إلغاء") } },
        )
    }
}

@Composable
fun Home(backend: Backend, onOpen: (Int) -> Unit) {
    val config = backend.config
    var stats by remember { mutableStateOf<Map<String, Int>>(emptyMap()) }
    LaunchedEffect(Unit) { if (backend.isAdmin) runCatching { stats = backend.stats() } }
    val tables = config.visibleTables(backend.isAdmin)
    Column(Modifier.fillMaxSize()) {
        Box(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(bottomStart = (config.radius + 14).dp, bottomEnd = (config.radius + 14).dp))
                .background(brand(config)).statusBarsPadding().padding(horizontal = 22.dp, vertical = 26.dp),
        ) {
            Column {
                Text(config.headline.ifEmpty { config.title }, color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Black)
                Spacer(Modifier.height(4.dp))
                Text(config.subtitle.ifEmpty { if (backend.isAdmin) "لوحة التحكم" else "أهلاً ${backend.name ?: "بك"}" }, color = Color.White.copy(alpha = 0.85f))
            }
        }
        Text(if (backend.isAdmin) "نظرة عامة" else "الأقسام", Modifier.padding(16.dp), fontSize = 18.sp, fontWeight = FontWeight.ExtraBold)
        LazyVerticalGrid(GridCells.Fixed(2), contentPadding = PaddingValues(horizontal = 12.dp), horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)) {
            items(tables) { t ->
                StatCard(iconFor(t.icon), t.label, stats[t.name]?.toString() ?: "›", config) { onOpen(tables.indexOf(t)) }
            }
            stats["_customers"]?.let { n -> item { StatCard(Icons.Rounded.Person, "العملاء", "$n", config) {} } }
        }
    }
}

@Composable
private fun StatCard(icon: ImageVector, label: String, value: String, config: AlphaConfig, onClick: () -> Unit) {
    Card(Modifier.fillMaxWidth().clickable(onClick = onClick), shape = RoundedCornerShape(config.radius.dp), border = lookBorder(config)) {
        Column(Modifier.padding(14.dp)) {
            Box(Modifier.size(40.dp).clip(RoundedCornerShape(12.dp)).background(MaterialTheme.colorScheme.primary.copy(alpha = 0.14f)), contentAlignment = Alignment.Center) {
                Icon(icon, null, tint = MaterialTheme.colorScheme.primary)
            }
            Spacer(Modifier.height(10.dp))
            Text(value, fontSize = 24.sp, fontWeight = FontWeight.Black)
            Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 13.sp, maxLines = 1)
        }
    }
}

@Composable
fun TableScreen(backend: Backend, table: TableCfg, refresh: Int, toast: (String) -> Unit) {
    val scope = rememberCoroutineScope()
    var rows by remember(table.name) { mutableStateOf<List<Rec>?>(null) }
    var error by remember(table.name) { mutableStateOf<String?>(null) }
    var query by remember(table.name) { mutableStateOf("") }
    var filter by remember(table.name) { mutableStateOf<String?>(null) }
    var open by remember { mutableStateOf<Rec?>(null) }
    var editing by remember { mutableStateOf<Rec?>(null) }
    var reloads by remember { mutableIntStateOf(0) }
    val badge = table.badgeColumn

    LaunchedEffect(table.name, refresh, reloads) {
        while (true) {
            try {
                rows = backend.list(table)
                error = null
            } catch (e: Exception) {
                if (rows == null) error = e.message
            }
            delay(20_000)
        }
    }
    val visible = (rows ?: emptyList()).filter { r ->
        (filter == null || badge == null || r[badge.name]?.toString() == filter) &&
            (query.isBlank() || table.columns.any { (r[it.name]?.toString() ?: "").contains(query.trim(), ignoreCase = true) })
    }
    Column(Modifier.fillMaxSize()) {
        OutlinedTextField(query, { query = it }, Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp),
            placeholder = { Text("بحث في ${table.label}") }, leadingIcon = { Icon(Icons.Rounded.Search, null) }, singleLine = true,
            shape = RoundedCornerShape(backend.config.radius.dp))
        if (badge != null && badge.options.isNotEmpty()) {
            LazyRow(contentPadding = PaddingValues(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                item { FilterChip(selected = filter == null, onClick = { filter = null }, label = { Text("الكل") }) }
                items(badge.options) { o -> FilterChip(selected = filter == o, onClick = { filter = o }, label = { Text(o) }) }
            }
        }
        when {
            error != null && rows == null -> Empty(Icons.Rounded.CloudOff, error!!) { OutlinedButton(onClick = { reloads++ }) { Text("إعادة المحاولة") } }
            rows == null -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            visible.isEmpty() -> Empty(iconFor(table.icon), if (rows!!.isEmpty()) "لا يوجد شيء في ${table.label} بعد" else "لا نتائج")
            else -> LazyColumn(contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 96.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items(visible, key = { it["id"].toString() }) { r -> RowCard(backend.config, table, r) { open = r } }
            }
        }
    }

    open?.let { r ->
        ModalBottomSheet(onDismissRequest = { open = null }) {
            Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 28.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                val url = table.imageColumn?.let { r[it.name]?.toString() } ?: ""
                if (url.startsWith("http")) {
                    AsyncImage(url, null, Modifier.fillMaxWidth().height(190.dp).clip(RoundedCornerShape(18.dp)), contentScale = ContentScale.Crop)
                }
                table.columns.filter { it.type != "image" && fmt(it, r[it.name]).isNotEmpty() }.forEach { c ->
                    Row {
                        Text(c.label, Modifier.width(110.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(fmt(c, r[c.name]), fontWeight = FontWeight.SemiBold)
                    }
                }
                if (backend.isAdmin) {
                    table.columns.filter { it.type == "choice" && it.adminOnly }.forEach { c ->
                        Text("تغيير ${c.label}", fontWeight = FontWeight.ExtraBold)
                        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            c.options.forEach { o ->
                                FilterChip(selected = r[c.name]?.toString() == o, onClick = {
                                    scope.launch {
                                        try {
                                            backend.update(table, r["id"].toString(), mapOf(c.name to o))
                                            open = null
                                            reloads++
                                            toast("تم التحديث ✓")
                                        } catch (e: Exception) {
                                            toast(e.message ?: "خطأ")
                                        }
                                    }
                                }, label = { Text(o) })
                            }
                        }
                    }
                }
                if (table.canEdit(backend.isAdmin, backend.isMine(r))) {
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                        Button(onClick = { editing = r; open = null }, Modifier.weight(1f).height(50.dp)) {
                            Icon(Icons.Rounded.Edit, null)
                            Spacer(Modifier.width(6.dp))
                            Text("تعديل")
                        }
                        IconButton(onClick = {
                            scope.launch {
                                try {
                                    backend.delete(table, r["id"].toString())
                                    open = null
                                    reloads++
                                    toast("تم الحذف")
                                } catch (e: Exception) {
                                    toast(e.message ?: "خطأ")
                                }
                            }
                        }) { Icon(Icons.Rounded.Delete, null, tint = MaterialTheme.colorScheme.error) }
                    }
                }
            }
        }
    }
    editing?.let { r ->
        RowForm(backend, table, r, onDismiss = { editing = null }) {
            editing = null
            reloads++
            toast("تم الحفظ ✓")
        }
    }
}

@Composable
private fun RowCard(config: AlphaConfig, table: TableCfg, r: Rec, onClick: () -> Unit) {
    val title = table.titleColumn
    val image = table.imageColumn
    val badge = table.badgeColumn
    val price = table.priceColumn
    val url = image?.let { r[it.name]?.toString() } ?: ""
    val details = table.columns.filter { it.show && it != title && it != image && it != badge && it != price && fmt(it, r[it.name]).isNotEmpty() }
        .take(3).joinToString("  •  ") { "${it.label}: ${fmt(it, r[it.name])}" }
    Card(Modifier.fillMaxWidth().clickable(onClick = onClick), shape = RoundedCornerShape(config.radius.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = if (config.style == "soft" || config.style == "neu") 4.dp else 0.dp),
        border = lookBorder(config)) {
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(58.dp).clip(RoundedCornerShape(14.dp)).background(MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)), contentAlignment = Alignment.Center) {
                if (url.startsWith("http")) AsyncImage(url, null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
                else Icon(iconFor(table.icon), null, tint = MaterialTheme.colorScheme.primary)
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(title?.let { fmt(it, r[it.name]) } ?: table.label, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                if (details.isNotEmpty()) Text(details, color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 13.sp, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Row(Modifier.fillMaxWidth().padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                    badge?.let { b ->
                        val v = fmt(b, r[b.name])
                        if (v.isNotEmpty()) {
                            Text(v, Modifier.clip(RoundedCornerShape(99.dp)).background(MaterialTheme.colorScheme.primary.copy(alpha = 0.15f))
                                .padding(horizontal = 10.dp, vertical = 3.dp), color = MaterialTheme.colorScheme.primary, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                    Spacer(Modifier.weight(1f))
                    price?.let { p -> Text(fmt(p, r[p.name]), color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Black) }
                }
            }
        }
    }
}

@Composable
fun RowForm(backend: Backend, table: TableCfg, row: Rec?, onDismiss: () -> Unit, onSaved: () -> Unit) {
    val scope = rememberCoroutineScope()
    val columns = table.columns.filter { !it.adminOnly || backend.isAdmin }
    val values = remember {
        mutableStateMapOf<String, Any?>().apply {
            columns.forEach { c ->
                val v = row?.get(c.name)
                put(c.name, when {
                    row != null -> if (v == JSONNull) null else v
                    c.type == "bool" -> c.default == "true"
                    c.type == "date" && (c.default == "today" || c.default == "now") -> java.time.LocalDate.now().toString()
                    c.type == "datetime" && c.default == "now" -> Instant.now().toString()
                    else -> c.default
                })
            }
        }
    }
    var busy by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    val shape = RoundedCornerShape(backend.config.radius.dp)
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 28.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(if (row != null) "تعديل ${table.label}" else "إضافة إلى ${table.label}", fontSize = 20.sp, fontWeight = FontWeight.ExtraBold)
            columns.forEach { c ->
                val label = c.label + if (c.required) " *" else ""
                when (c.type) {
                    "bool" -> Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Text(c.label, Modifier.weight(1f))
                        Switch(checked = values[c.name] == true || values[c.name]?.toString() == "true", onCheckedChange = { values[c.name] = it })
                    }
                    "choice" -> {
                        var expanded by remember { mutableStateOf(false) }
                        ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
                            OutlinedTextField(values[c.name]?.toString() ?: "", {}, readOnly = true, label = { Text(label) }, shape = shape,
                                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) },
                                modifier = Modifier.fillMaxWidth().menuAnchor(MenuAnchorType.PrimaryNotEditable))
                            ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                                c.options.forEach { o -> DropdownMenuItem(text = { Text(o) }, onClick = { values[c.name] = o; expanded = false }) }
                            }
                        }
                    }
                    else -> OutlinedTextField(
                        values[c.name]?.toString() ?: "", { values[c.name] = it }, Modifier.fillMaxWidth(),
                        label = { Text(label) }, shape = shape,
                        placeholder = {
                            val hint = when (c.type) {
                                "date" -> "2026-01-31"
                                "datetime" -> "2026-01-31T18:30"
                                "image" -> "https://…"
                                else -> ""
                            }
                            if (hint.isNotEmpty()) Text(hint)
                        },
                        singleLine = c.type != "longtext", minLines = if (c.type == "longtext") 3 else 1,
                        keyboardOptions = KeyboardOptions(keyboardType = when (c.type) {
                            "int" -> KeyboardType.Number
                            "decimal" -> KeyboardType.Decimal
                            "phone" -> KeyboardType.Phone
                            "email" -> KeyboardType.Email
                            "image" -> KeyboardType.Uri
                            else -> KeyboardType.Text
                        }),
                    )
                }
            }
            message?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            Button(onClick = {
                val missing = columns.firstOrNull { it.required && (values[it.name] == null || values[it.name].toString().isBlank()) }
                if (missing != null) {
                    message = "«${missing.label}» مطلوب"
                    return@Button
                }
                busy = true
                scope.launch {
                    try {
                        val data: Map<String, Any?> = values.toMap()
                        if (row != null) backend.update(table, row["id"].toString(), data) else backend.insert(table, data)
                        onSaved()
                    } catch (e: Exception) {
                        message = e.message
                    } finally {
                        busy = false
                    }
                }
            }, enabled = !busy, modifier = Modifier.fillMaxWidth().height(52.dp), shape = shape) {
                Text(if (row != null) "حفظ التعديل" else "إضافة", fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
fun Notes(backend: Backend, refresh: Int, onSeen: () -> Unit) {
    var items by remember { mutableStateOf<List<AppNotification>?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(refresh) {
        try {
            items = backend.notifications()
            backend.markSeen()
            onSeen()
        } catch (e: Exception) {
            error = e.message
        }
    }
    val fmt = DateTimeFormatter.ofPattern("yyyy/MM/dd HH:mm").withZone(ZoneId.systemDefault())
    when {
        error != null && items == null -> Empty(Icons.Rounded.CloudOff, error!!)
        items == null -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        items!!.isEmpty() -> Empty(Icons.Rounded.Notifications, "لا توجد إشعارات بعد")
        else -> LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            items(items!!) { n ->
                Card(Modifier.fillMaxWidth(), shape = RoundedCornerShape(backend.config.radius.dp)) {
                    Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Rounded.Notifications, null, tint = MaterialTheme.colorScheme.primary)
                        Spacer(Modifier.width(12.dp))
                        Column {
                            Text(n.title, fontWeight = if (n.read) FontWeight.SemiBold else FontWeight.Black)
                            if (n.body.isNotEmpty()) Text(n.body, color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 13.sp)
                            Text(fmt.format(n.at), color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 12.sp)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun Me(backend: Backend, onSignOut: () -> Unit) {
    val config = backend.config
    val label = backend.name ?: backend.email?.substringBefore("@") ?: "مستخدم"
    Column(Modifier.fillMaxSize().padding(16.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Card(Modifier.fillMaxWidth(), shape = RoundedCornerShape(config.radius.dp)) {
            Row(Modifier.padding(18.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(60.dp).clip(CircleShape).background(brand(config)), contentAlignment = Alignment.Center) {
                    Text(label.take(1).uppercase(), color = Color.White, fontSize = 24.sp, fontWeight = FontWeight.Black)
                }
                Spacer(Modifier.width(14.dp))
                Column {
                    Text(label, fontWeight = FontWeight.Black, fontSize = 18.sp)
                    backend.email?.let { Text(it, color = MaterialTheme.colorScheme.onSurfaceVariant) }
                    Text(if (backend.isAdmin) "مدير" else "عميل", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                }
            }
        }
        Card(Modifier.fillMaxWidth(), shape = RoundedCornerShape(config.radius.dp)) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row { Text("التطبيق", Modifier.weight(1f)); Text(config.title) }
                Row { Text("البيانات", Modifier.weight(1f)); Text(if (backend.kind == "supabase") "Supabase" else "على الجهاز") }
                Row { Text("الإشعارات", Modifier.weight(1f)); Text(if (config.push) "مفعّلة" else "داخل التطبيق") }
            }
        }
        if (config.needsAccount && backend.kind != "none") {
            OutlinedButton(onClick = onSignOut, modifier = Modifier.fillMaxWidth()) {
                Icon(Icons.AutoMirrored.Rounded.Logout, null)
                Spacer(Modifier.width(6.dp))
                Text("تسجيل الخروج")
            }
        }
        Text("صُنع بواسطة Alpha", Modifier.fillMaxWidth().padding(top = 12.dp), color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 12.sp)
    }
}
