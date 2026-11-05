"""Made with Alpha (Python / Flet 1.x). Screens, data and rules come from alpha_config.py (the design in Alpha)."""
from datetime import datetime

import flet as ft

from alpha_backend import BackendError, NeedsConfirmation, create_backend
from alpha_config import CONFIG

ICONS = {
    "shopping_bag": ft.Icons.SHOPPING_BAG_ROUNDED, "receipt": ft.Icons.RECEIPT_LONG_ROUNDED, "star": ft.Icons.STAR_ROUNDED,
    "restaurant": ft.Icons.RESTAURANT_ROUNDED, "delivery": ft.Icons.DELIVERY_DINING_ROUNDED,
    "medical": ft.Icons.MEDICAL_SERVICES_ROUNDED, "calendar": ft.Icons.CALENDAR_MONTH_ROUNDED,
    "event": ft.Icons.EVENT_AVAILABLE_ROUNDED, "place": ft.Icons.PLACE_ROUNDED, "school": ft.Icons.SCHOOL_ROUNDED,
    "campaign": ft.Icons.CAMPAIGN_ROUNDED, "book": ft.Icons.MENU_BOOK_ROUNDED, "chat": ft.Icons.CHAT_BUBBLE_ROUNDED,
    "person": ft.Icons.PERSON_ROUNDED, "wallet": ft.Icons.ACCOUNT_BALANCE_WALLET_ROUNDED,
    "checklist": ft.Icons.CHECKLIST_ROUNDED, "home": ft.Icons.HOME_ROUNDED, "settings": ft.Icons.SETTINGS_ROUNDED,
    "car": ft.Icons.DIRECTIONS_CAR_ROUNDED, "phone": ft.Icons.PHONE_ROUNDED, "photo": ft.Icons.PHOTO_ROUNDED,
    "store": ft.Icons.STOREFRONT_ROUNDED, "work": ft.Icons.WORK_ROUNDED, "payments": ft.Icons.PAYMENTS_ROUNDED,
}


def icon_for(name):
    return ICONS.get(name, ft.Icons.VIEW_LIST_ROUNDED)


def fmt(col, value):
    if value is None or value == "":
        return ""
    t = col.get("type")
    if t == "bool":
        return "نعم" if value in (True, "true") else "لا"
    if t == "decimal":
        try:
            n = float(value)
            return str(int(n)) if n == int(n) else f"{n:.2f}"
        except (TypeError, ValueError):
            return str(value)
    if t in ("date", "datetime"):
        try:
            d = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
            return d.strftime("%Y/%m/%d") if t == "date" else d.astimezone().strftime("%Y/%m/%d  %H:%M")
        except ValueError:
            return str(value)
    return str(value)


def title_col(t):
    cols = t.get("columns", [])
    return next((c for c in cols if c.get("type") in ("text", "choice")), cols[0] if cols else None)


def col_of(t, kind, admin_only=None):
    for c in t.get("columns", []):
        if c.get("type") == kind and (admin_only is None or bool(c.get("adminOnly")) == admin_only):
            return c
    return None


def badge_col(t):
    return col_of(t, "choice", True) or col_of(t, "choice")


def main(page: ft.Page):
    app = CONFIG.get("app", {})
    theme = CONFIG.get("theme", {})
    role = app.get("role", "single")
    seed = theme.get("seed", "#6E4BFF")
    accent = theme.get("accent", "#2DD4BF")
    radius = int(theme.get("radius", 18))
    b = create_backend(CONFIG)

    page.title = app.get("title", "Alpha")
    page.rtl = app.get("rtl", True) is not False
    page.theme = ft.Theme(color_scheme_seed=seed)
    page.dark_theme = ft.Theme(color_scheme_seed=seed)
    page.theme_mode = {"light": ft.ThemeMode.LIGHT, "system": ft.ThemeMode.SYSTEM}.get(theme.get("mode"), ft.ThemeMode.DARK)
    page.padding = 0
    page.spacing = 0

    state = {"tab": 0, "query": "", "filter": None, "rows": {}}
    body = ft.Container(expand=True)

    def toast(text, error=False):
        page.show_dialog(ft.SnackBar(content=ft.Text(text), bgcolor=ft.Colors.RED_700 if error else None))

    def gradient():
        return ft.LinearGradient(colors=[seed, accent], begin=ft.Alignment.TOP_RIGHT, end=ft.Alignment.BOTTOM_LEFT)

    def card(content, on_click=None, padding=14):
        style = theme.get("style")
        border = (ft.Border.all(2.5, "#0B0B0F") if style == "brutal"
                  else ft.Border.all(1.5, ft.Colors.with_opacity(0.45, seed)) if style == "outline" else None)
        return ft.Card(
            content=ft.Container(content=content, padding=padding, on_click=on_click, border_radius=radius, border=border),
            shape=ft.RoundedRectangleBorder(radius=radius),
            elevation=4 if style in ("soft", "neu") else 0,
        )

    def hero(title, subtitle):
        return ft.Container(
            gradient=gradient(),
            padding=ft.Padding.only(left=22, right=22, top=34, bottom=26),
            border_radius=ft.BorderRadius.only(bottom_left=radius + 14, bottom_right=radius + 14),
            content=ft.Column([
                ft.Text(title, size=26, weight=ft.FontWeight.W_900, color=ft.Colors.WHITE),
                ft.Text(subtitle, size=14, color=ft.Colors.with_opacity(0.85, ft.Colors.WHITE)),
            ], spacing=4),
        )

    def empty(icon, text, action=None):
        items = [ft.Icon(icon, size=48, color=seed), ft.Text(text, text_align=ft.TextAlign.CENTER, color=ft.Colors.ON_SURFACE_VARIANT)]
        if action:
            items.append(action)
        return ft.Container(content=ft.Column(items, horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=12),
                            padding=40, alignment=ft.Alignment.CENTER)

    def visible_tables():
        return [t for t in CONFIG.get("tables", []) if t.get("owner") != "admin" or b.is_admin or role == "admin"]

    def can_add(t):
        return b.is_admin or t.get("owner") in ("customer", "public")

    def can_edit(t, row):
        return b.is_admin or (t.get("owner") in ("customer", "public") and b.is_mine(row))

    # ---------------- login ----------------
    def show_login():
        page.navigation_bar = None
        page.floating_action_button = None
        mode = {"value": "login"}  # login | signup | code
        name = ft.TextField(label="الاسم", prefix_icon=ft.Icons.PERSON_ROUNDED, border_radius=radius)
        phone = ft.TextField(label="رقم الهاتف", prefix_icon=ft.Icons.PHONE_ROUNDED, keyboard_type=ft.KeyboardType.PHONE,
                             rtl=False, border_radius=radius)
        email = ft.TextField(label="البريد الإلكتروني", prefix_icon=ft.Icons.ALTERNATE_EMAIL_ROUNDED,
                             keyboard_type=ft.KeyboardType.EMAIL, rtl=False, border_radius=radius)
        password = ft.TextField(label="كلمة المرور", prefix_icon=ft.Icons.KEY_ROUNDED, password=True,
                                can_reveal_password=True, rtl=False, border_radius=radius)
        code = ft.TextField(label="رمز التأكيد (6 أرقام)", keyboard_type=ft.KeyboardType.NUMBER, max_length=6,
                            text_align=ft.TextAlign.CENTER, rtl=False, border_radius=radius)
        hint = ft.Text("", text_align=ft.TextAlign.CENTER)
        go = ft.FilledButton(content="دخول", height=52, expand=True)
        switch = ft.TextButton(content="ما عندي حساب؟ أنشئ واحداً")
        resend = ft.TextButton(content="أرسل الرمز مرة أخرى")
        back = ft.TextButton(content="رجوع لتسجيل الدخول")

        def redraw():
            m = mode["value"]
            name.visible = phone.visible = m == "signup"
            email.visible = password.visible = m != "code"
            code.visible = hint.visible = resend.visible = back.visible = m == "code"
            switch.visible = m != "code"
            hint.value = f"أدخل الرمز الذي أرسلناه إلى {(email.value or '').strip()}"
            go.content = {"signup": "إنشاء الحساب", "code": "تأكيد"}.get(m, "دخول")
            switch.content = "عندي حساب، سجّل دخولي" if m == "signup" else "ما عندي حساب؟ أنشئ واحداً"
            page.update()

        def toggle(_):
            mode["value"] = "login" if mode["value"] == "signup" else "signup"
            redraw()

        def to_login(_):
            mode["value"] = "login"
            redraw()

        def do_resend(_):
            try:
                b.resend_code(email.value or "")
                toast("أُرسل الرمز من جديد")
            except BackendError as e:
                toast(str(e), True)

        def submit(_):
            m = mode["value"]
            if m == "code":
                if not (code.value or "").strip().isdigit() or len((code.value or "").strip()) != 6:
                    toast("اكتب الرمز من 6 أرقام", True)
                    return
            elif "@" not in (email.value or "") or len(password.value or "") < 6:
                toast("اكتب بريداً صحيحاً وكلمة مرور من 6 أحرف", True)
                return
            elif m == "signup" and (len((name.value or "").strip()) < 2 or len((phone.value or "").strip()) < 7):
                toast("اكتب الاسم ورقم الهاتف", True)
                return
            go.disabled = True
            page.update()
            try:
                if m == "signup":
                    if b.sign_up(name.value or "", phone.value or "", email.value, password.value):
                        mode["value"] = "code"
                        redraw()
                        toast("أرسلنا رمز التأكيد إلى بريدك")
                        return
                elif m == "code":
                    b.verify_code(email.value, code.value, password.value)
                else:
                    b.sign_in(email.value, password.value)
                show_home()
            except NeedsConfirmation:
                mode["value"] = "code"
                redraw()
                toast("أكّد بريدك أولاً: أدخل الرمز الذي وصلك")
            except BackendError as e:
                toast(str(e), True)
            finally:
                go.disabled = False
                page.update()

        go.on_click = submit
        switch.on_click = toggle
        resend.on_click = do_resend
        back.on_click = to_login
        body.content = ft.ListView([
            hero(app.get("title", ""), "لوحة الإدارة" if role == "admin" else "مرحباً بك"),
            ft.Container(padding=18, content=card(ft.Column([hint, name, phone, email, password, code, ft.Row([go]), switch, resend, back],
                                                            spacing=12), padding=20)),
        ], expand=True)
        redraw()

    def check_update():
        """In-app updates: the build publishes each version at a public link; the browser downloads it."""
        u = CONFIG.get("update") or {}
        if not u.get("url") or not u.get("version"):
            return
        try:
            import requests
            j = requests.get(u["url"], params={"t": int(datetime.now().timestamp())}, timeout=15).json()
        except Exception:
            return
        if not (int(j.get("version") or 0) > int(u["version"])) or not j.get("apk"):
            return

        def update(_):
            page.pop_dialog()
            page.run_task(ft.UrlLauncher().launch_url, j["apk"], mode=ft.LaunchMode.EXTERNAL_APPLICATION)
            toast("يتم التحميل… افتح الملف عند انتهائه واضغط «تثبيت»")

        page.show_dialog(ft.AlertDialog(
            title=ft.Text("تحديث جديد"),
            content=ft.Text(f"النسخة {j.get('name') or j['version']} جاهزة." + (f"\n\n{j['notes']}" if j.get("notes") else "")),
            actions=[ft.TextButton(content="لاحقاً", on_click=lambda _: page.pop_dialog()), ft.FilledButton(content="حدّث الآن", on_click=update)]))

    # ---------------- tabs ----------------
    def home_view():
        tables = visible_tables()
        stats = {}
        if b.is_admin:
            try:
                stats = b.stats()
            except BackendError:
                stats = {}
        tiles = []
        for i, t in enumerate(tables):
            tiles.append(card(ft.Column([
                ft.Container(content=ft.Icon(icon_for(t.get("icon")), color=seed), padding=8, border_radius=12,
                             bgcolor=ft.Colors.with_opacity(0.14, seed)),
                ft.Text(str(stats.get(t["name"], "›")), size=24, weight=ft.FontWeight.W_900),
                ft.Text(t.get("label", t["name"]), color=ft.Colors.ON_SURFACE_VARIANT, size=13),
            ], spacing=6), on_click=lambda _, i=i: open_table(i)))
        if "_customers" in stats:
            tiles.append(card(ft.Column([ft.Icon(ft.Icons.GROUPS_ROUNDED, color=seed),
                                         ft.Text(str(stats["_customers"]), size=24, weight=ft.FontWeight.W_900),
                                         ft.Text("العملاء", color=ft.Colors.ON_SURFACE_VARIANT, size=13)], spacing=6)))
        hello = f"أهلاً {b.name}" if b.name else "أهلاً بك"
        return ft.ListView([
            hero(app.get("headline") or app.get("title", ""), app.get("subtitle") or ("لوحة التحكم" if b.is_admin else hello)),
            ft.Container(ft.Text("نظرة عامة" if b.is_admin else "الأقسام", size=18, weight=ft.FontWeight.W_800),
                         padding=ft.Padding.only(left=16, right=16, top=18, bottom=6)),
            ft.Container(ft.GridView(tiles, runs_count=2, child_aspect_ratio=1.3, spacing=6, run_spacing=6),
                         padding=ft.Padding.symmetric(horizontal=12)),
        ], expand=True)

    def table_view(t):
        rows_box = ft.Column(spacing=0)
        badge = badge_col(t)

        def draw():
            rows = state["rows"].get(t["name"])
            if rows is None:
                rows_box.controls = [ft.Container(ft.ProgressRing(), alignment=ft.Alignment.CENTER, padding=40)]
                return
            q = state["query"].strip().lower()
            shown = [r for r in rows
                     if (state["filter"] is None or not badge or r.get(badge["name"]) == state["filter"])
                     and (not q or any(q in str(r.get(c["name"]) or "").lower() for c in t.get("columns", [])))]
            if not shown:
                rows_box.controls = [empty(icon_for(t.get("icon")), "لا نتائج" if rows else f"لا يوجد شيء في {t.get('label')} بعد")]
                return
            rows_box.controls = [row_card(t, r) for r in shown]

        def load(_=None):
            try:
                state["rows"][t["name"]] = b.list(t)
            except BackendError as e:
                toast(str(e), True)
                state["rows"][t["name"]] = []
            draw()
            page.update()

        def on_search(e):
            state["query"] = e.control.value or ""
            draw()
            page.update()

        def set_filter(value):
            state["filter"] = value
            for chip in chips.controls:
                chip.selected = chip.data == value
            draw()
            page.update()

        chips = ft.Row(scroll=ft.ScrollMode.AUTO, spacing=8)
        if badge and badge.get("options"):
            chips.controls = [ft.Chip(label=ft.Text("الكل"), selected=True, data=None, on_select=lambda _: set_filter(None))] + [
                ft.Chip(label=ft.Text(o), data=o, on_select=lambda _, o=o: set_filter(o)) for o in badge["options"]]
        state["reload"] = load
        draw()
        page.run_thread(load)
        return ft.ListView([
            ft.Container(ft.TextField(hint_text=f"بحث في {t.get('label')}", prefix_icon=ft.Icons.SEARCH_ROUNDED,
                                      border_radius=radius, on_change=on_search), padding=ft.Padding.only(left=16, right=16, top=12)),
            ft.Container(chips, padding=ft.Padding.symmetric(horizontal=16, vertical=6), visible=bool(chips.controls)),
            ft.Container(rows_box, padding=ft.Padding.only(left=12, right=12, bottom=90)),
        ], expand=True)

    def row_card(t, r):
        title = title_col(t)
        image = col_of(t, "image")
        badge = badge_col(t)
        price = col_of(t, "decimal")
        details = "  •  ".join(f"{c.get('label')}: {fmt(c, r.get(c['name']))}" for c in t.get("columns", [])
                               if c.get("show", True) and c not in (title, image, badge, price) and r.get(c["name"]) not in (None, ""))[:160]
        url = str(r.get(image["name"]) or "") if image else ""
        thumb = (ft.Image(src=url, width=58, height=58, fit=ft.BoxFit.COVER, border_radius=14) if url.startswith("http")
                 else ft.Container(ft.Icon(icon_for(t.get("icon")), color=seed), width=58, height=58, border_radius=14,
                                   bgcolor=ft.Colors.with_opacity(0.12, seed), alignment=ft.Alignment.CENTER))
        meta = []
        if badge and r.get(badge["name"]):
            meta.append(ft.Container(ft.Text(str(r.get(badge["name"])), size=12, weight=ft.FontWeight.W_700, color=seed),
                                     bgcolor=ft.Colors.with_opacity(0.15, seed), border_radius=99,
                                     padding=ft.Padding.symmetric(horizontal=10, vertical=3)))
        if price and r.get(price["name"]) is not None:
            meta.append(ft.Text(fmt(price, r.get(price["name"])), color=seed, weight=ft.FontWeight.W_900))
        return card(ft.Row([
            thumb,
            ft.Column([
                ft.Text(fmt(title, r.get(title["name"])) if title else t.get("label"), weight=ft.FontWeight.W_800, size=16,
                        max_lines=1),
                ft.Text(details, size=13, color=ft.Colors.ON_SURFACE_VARIANT, max_lines=2, visible=bool(details)),
                ft.Row(meta, alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
            ], spacing=4, expand=True),
        ], spacing=12), on_click=lambda _: details_sheet(t, r), padding=12)

    def details_sheet(t, r):
        lines = []
        for c in t.get("columns", []):
            if c.get("type") == "image" or r.get(c["name"]) in (None, ""):
                continue
            lines.append(ft.Row([ft.Text(c.get("label"), width=110, color=ft.Colors.ON_SURFACE_VARIANT),
                                 ft.Text(fmt(c, r.get(c["name"])), weight=ft.FontWeight.W_600, expand=True, selectable=True)]))
        if b.is_admin:
            for c in t.get("columns", []):
                if c.get("type") == "choice" and c.get("adminOnly"):
                    lines.append(ft.Text(f"تغيير {c.get('label')}", weight=ft.FontWeight.W_800))
                    lines.append(ft.Row([ft.Chip(label=ft.Text(o), selected=r.get(c["name"]) == o,
                                                 on_select=lambda _, c=c, o=o: set_value(t, r, c["name"], o))
                                         for o in c.get("options", [])], wrap=True))
        if can_edit(t, r):
            lines.append(ft.Row([
                ft.FilledButton(content="تعديل", icon=ft.Icons.EDIT_ROUNDED, expand=True,
                                on_click=lambda _: (page.pop_dialog(), form_sheet(t, r))),
                ft.IconButton(icon=ft.Icons.DELETE_OUTLINE_ROUNDED, icon_color=ft.Colors.RED_400,
                              on_click=lambda _: confirm_delete(t, r)),
            ]))
        page.show_dialog(ft.BottomSheet(content=ft.Container(ft.Column(lines, tight=True, spacing=10, scroll=ft.ScrollMode.AUTO),
                                                             padding=20), show_drag_handle=True))

    def set_value(t, r, name, value):
        try:
            b.update(t, r["id"], {name: value})
            page.pop_dialog()
            toast("تم التحديث ✓")
            reload()
        except BackendError as e:
            toast(str(e), True)

    def confirm_delete(t, r):
        def yes(_):
            page.pop_dialog()
            try:
                b.delete(t, r["id"])
                page.pop_dialog()
                toast("تم الحذف")
                reload()
            except BackendError as e:
                toast(str(e), True)

        page.show_dialog(ft.AlertDialog(title=ft.Text("حذف؟"), content=ft.Text("لا يمكن التراجع عن الحذف."),
                                        actions=[ft.TextButton(content="إلغاء", on_click=lambda _: page.pop_dialog()),
                                                 ft.FilledButton(content="حذف", on_click=yes)]))

    def form_sheet(t, r=None):
        fields = {}
        controls = [ft.Text(("تعديل " if r else "إضافة إلى ") + t.get("label", ""), size=20, weight=ft.FontWeight.W_800)]
        for c in t.get("columns", []):
            if c.get("adminOnly") and not b.is_admin:
                continue
            value = r.get(c["name"]) if r else c.get("default")
            label = c.get("label", c["name"]) + (" *" if c.get("required") else "")
            kind = c.get("type")
            if kind == "bool":
                ctl = ft.Switch(label=c.get("label"), value=value in (True, "true"))
            elif kind == "choice":
                ctl = ft.Dropdown(label=label, value=value if value in c.get("options", []) else None,
                                  options=[ft.DropdownOption(key=o, text=o) for o in c.get("options", [])], expand=True)
            else:
                if kind == "date" and value in ("today", "now"):
                    value = datetime.now().date().isoformat()
                if kind == "datetime" and value == "now":
                    value = datetime.now().isoformat(timespec="minutes")
                ctl = ft.TextField(
                    label=label, value="" if value is None else str(value), border_radius=radius,
                    multiline=kind == "longtext", min_lines=3 if kind == "longtext" else 1,
                    max_lines=6 if kind == "longtext" else 1,
                    hint_text={"date": "2026-01-31", "datetime": "2026-01-31T18:30", "image": "https://…"}.get(kind),
                    keyboard_type={"int": ft.KeyboardType.NUMBER, "decimal": ft.KeyboardType.NUMBER,
                                   "phone": ft.KeyboardType.PHONE, "email": ft.KeyboardType.EMAIL,
                                   "image": ft.KeyboardType.URL}.get(kind, ft.KeyboardType.TEXT),
                    rtl=kind not in ("int", "decimal", "phone", "email", "image", "date", "datetime"),
                )
            fields[c["name"]] = (c, ctl)
            controls.append(ctl)

        def save(_):
            values = {}
            for name, (c, ctl) in fields.items():
                v = ctl.value
                if c.get("required") and (v is None or str(v).strip() == ""):
                    toast(f"«{c.get('label')}» مطلوب", True)
                    return
                if c.get("type") in ("date", "datetime") and v:
                    try:
                        datetime.fromisoformat(str(v))
                    except ValueError:
                        toast(f"«{c.get('label')}»: اكتب التاريخ مثل 2026-01-31", True)
                        return
                values[name] = v
            try:
                if r:
                    b.update(t, r["id"], values)
                else:
                    b.insert(t, values)
                page.pop_dialog()
                toast("تم الحفظ ✓" if r else "تمت الإضافة ✓")
                reload()
            except BackendError as e:
                toast(str(e), True)

        controls.append(ft.Row([ft.FilledButton(content="حفظ التعديل" if r else "إضافة", icon=ft.Icons.CHECK_ROUNDED,
                                                height=52, expand=True, on_click=save)]))
        page.show_dialog(ft.BottomSheet(content=ft.Container(ft.Column(controls, tight=True, spacing=12, scroll=ft.ScrollMode.AUTO),
                                                             padding=20), show_drag_handle=True, scrollable=True))

    def notes_view():
        box = ft.Column(spacing=0)

        def load(_=None):
            try:
                items = b.notifications()
                b.mark_seen()
            except BackendError as e:
                box.controls = [empty(ft.Icons.CLOUD_OFF_ROUNDED, str(e))]
                page.update()
                return
            box.controls = [card(ft.Row([
                ft.Icon(ft.Icons.NOTIFICATIONS_ACTIVE_ROUNDED if not n["read"] else ft.Icons.NOTIFICATIONS_ROUNDED, color=seed),
                ft.Column([ft.Text(n["title"], weight=ft.FontWeight.W_800),
                           ft.Text(n["body"], size=13, color=ft.Colors.ON_SURFACE_VARIANT, visible=bool(n["body"])),
                           ft.Text(n["at"].astimezone().strftime("%Y/%m/%d %H:%M"), size=12, color=ft.Colors.ON_SURFACE_VARIANT)],
                          spacing=2, expand=True)]), padding=12) for n in items] or [
                empty(ft.Icons.NOTIFICATIONS_NONE_ROUNDED, "لا توجد إشعارات بعد")]
            page.update()

        state["reload"] = load
        page.run_thread(load)
        return ft.ListView([ft.Container(box, padding=ft.Padding.only(left=12, right=12, top=12, bottom=90))], expand=True)

    def compose(_=None):
        title = ft.TextField(label="العنوان", border_radius=radius)
        text = ft.TextField(label="النص", multiline=True, min_lines=2, border_radius=radius)

        def send(_):
            if not (title.value or "").strip():
                return
            try:
                b.notify("customer" if b.is_admin else "admin", title.value.strip(), (text.value or "").strip())
                page.pop_dialog()
                toast("تم الإرسال ✓")
                reload()
            except BackendError as e:
                toast(str(e), True)

        page.show_dialog(ft.AlertDialog(title=ft.Text("إشعار لكل العملاء" if b.is_admin else "رسالة للإدارة"),
                                        content=ft.Column([title, text], tight=True),
                                        actions=[ft.TextButton(content="إلغاء", on_click=lambda _: page.pop_dialog()),
                                                 ft.FilledButton(content="إرسال", on_click=send)]))

    def me_view():
        label = b.name or (b.email.split("@")[0] if b.email else "مستخدم")
        items = [
            card(ft.Row([ft.CircleAvatar(content=ft.Text(label[:1].upper(), size=22, weight=ft.FontWeight.W_900), radius=30, bgcolor=seed),
                         ft.Column([ft.Text(label, size=18, weight=ft.FontWeight.W_900),
                                    ft.Text(b.email or "", color=ft.Colors.ON_SURFACE_VARIANT, visible=bool(b.email)),
                                    ft.Text("مدير" if b.is_admin else "عميل", color=seed, weight=ft.FontWeight.W_700)], spacing=2)],
                        spacing=14), padding=18),
            card(ft.Column([
                ft.Row([ft.Text("التطبيق", expand=True), ft.Text(app.get("title", ""))]),
                ft.Row([ft.Text("البيانات", expand=True), ft.Text("Supabase" if b.kind == "supabase" else "على الجهاز")]),
            ], spacing=10)),
        ]
        if b.needs_account and b.kind != "none":
            def out(_):
                b.sign_out()
                start()
            items.append(ft.Container(ft.OutlinedButton(content="تسجيل الخروج", icon=ft.Icons.LOGOUT_ROUNDED, on_click=out),
                                      padding=8))
        items.append(ft.Container(ft.Text("صُنع بواسطة Alpha", size=12, color=ft.Colors.ON_SURFACE_VARIANT),
                                  alignment=ft.Alignment.CENTER, padding=20))
        return ft.ListView([ft.Container(ft.Column(items), padding=16)], expand=True)

    def reload():
        fn = state.get("reload")
        if fn:
            fn()

    def tabs():
        tables = visible_tables()
        out = [("الرئيسية", ft.Icons.SPACE_DASHBOARD_ROUNDED, "home", None)]
        out += [(t.get("label", t["name"]), icon_for(t.get("icon")), "table", t) for t in tables[:3]]
        if b.kind != "none":
            out.append(("الإشعارات", ft.Icons.NOTIFICATIONS_ROUNDED, "notes", None))
        out.append(("حسابي", ft.Icons.PERSON_ROUNDED, "me", None))
        return out

    def open_table(i):
        state["tab"] = min(i + 1, len(tabs()) - 1)
        draw_tab()

    def draw_tab():
        items = tabs()
        state["tab"] = min(state["tab"], len(items) - 1)
        state["query"], state["filter"], state["reload"] = "", None, None
        _, _, kind, table = items[state["tab"]]
        page.floating_action_button = None
        if kind == "home":
            body.content = home_view()
        elif kind == "table":
            body.content = table_view(table)
            if can_add(table):
                page.floating_action_button = ft.FloatingActionButton(icon=ft.Icons.ADD_ROUNDED, bgcolor=seed,
                                                                      on_click=lambda _: form_sheet(table))
        elif kind == "notes":
            body.content = notes_view()
            page.floating_action_button = ft.FloatingActionButton(icon=ft.Icons.SEND_ROUNDED, bgcolor=seed, on_click=compose)
        else:
            body.content = me_view()
        page.navigation_bar.selected_index = state["tab"]
        page.update()

    def show_home():
        if role == "admin" and not b.is_admin:
            def out(_):
                b.sign_out()
                start()
            page.navigation_bar = None
            body.content = empty(ft.Icons.GPP_BAD_ROUNDED, f"الحساب {b.email or ''} ليس مديراً.\nأضف بريده كمدير في Alpha.",
                                 ft.FilledButton(content="تسجيل الخروج", on_click=out))
            page.update()
            return

        def change(e):
            state["tab"] = int(e.control.selected_index)
            draw_tab()

        page.navigation_bar = ft.NavigationBar(
            destinations=[ft.NavigationBarDestination(icon=i, label=label) for label, i, _, _ in tabs()],
            on_change=change, selected_index=0)
        state["tab"] = 0
        draw_tab()

    def start():
        body.content = ft.Container(ft.ProgressRing(), alignment=ft.Alignment.CENTER, expand=True)
        page.update()
        try:
            b.init()
        except BackendError as e:
            body.content = empty(ft.Icons.CLOUD_OFF_ROUNDED, str(e), ft.FilledButton(content="إعادة المحاولة", on_click=lambda _: start()))
            page.update()
            return
        if not b.signed_in:
            show_login()
        else:
            show_home()
        page.run_thread(check_update)

    page.add(ft.SafeArea(body, expand=True))
    start()


if __name__ == "__main__":
    ft.run(main)
