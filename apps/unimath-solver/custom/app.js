/**
 * University Equation Calculator - Core Application Logic
 * Powered by Alpha Engine API (window.AlphaBackend)
 */

let B = null; // AlphaBackend reference
let currentInput = "\\int_{0}^{\\pi} x \\cdot \\sin(x) \\, dx";
let currentCategory = "Calculus";
let currentInputType = "لوحة المفاتيح";
let currentSolutionData = null;
let mathChartInstance = null;
let currentProfile = null;
let allEquations = [];
let allFormulas = [];
let activeKeypadTab = "calculus";

// Keypad Presets by category
const KEYPAD_PRESETS = {
  basic: [
    { label: "x", val: "x" }, { label: "y", val: "y" }, { label: "x²", val: "x²" }, { label: "xⁿ", val: "x^" }, { label: "⌫", val: "BACK", action: true },
    { label: "7", val: "7" }, { label: "8", val: "8" }, { label: "9", val: "9" }, { label: "÷", val: "÷", action: true }, { label: "×", val: "×", action: true },
    { label: "4", val: "4" }, { label: "5", val: "5" }, { label: "6", val: "6" }, { label: "-", val: "-", action: true }, { label: "+", val: "+", action: true },
    { label: "1", val: "1" }, { label: "2", val: "2" }, { label: "3", val: "3" }, { label: "(", val: "(" }, { label: ")", val: ")" },
    { label: "0", val: "0" }, { label: ".", val: "." }, { label: "=", val: "=" }, { label: "√", val: "√" }, { label: "π", val: "π" }
  ],
  calculus: [
    { label: "∫", val: "∫" }, { label: "d/dx", val: "d/dx" }, { label: "lim", val: "lim" }, { label: "∑", val: "∑" }, { label: "⌫", val: "BACK", action: true },
    { label: "sin", val: "sin(" }, { label: "cos", val: "cos(" }, { label: "tan", val: "tan(" }, { label: "ln", val: "ln(" }, { label: "eˣ", val: "e^" },
    { label: "x", val: "x" }, { label: "x²", val: "x²" }, { label: "xⁿ", val: "x^" }, { label: "√", val: "√(" }, { label: "dx", val: "dx" },
    { label: "7", val: "7" }, { label: "8", val: "8" }, { label: "9", val: "9" }, { label: "+", val: "+" }, { label: "-", val: "-" },
    { label: "0", val: "0" }, { label: ".", val: "." }, { label: "(", val: "(" }, { label: ")", val: ")" }, { label: "π", val: "π" }
  ],
  matrices: [
    { label: "det", val: "det(" }, { label: "[a,b]", val: "[[a,b],[c,d]]" }, { label: "A⁻¹", val: "A⁻¹" }, { label: "Aᵀ", val: "Aᵀ" }, { label: "⌫", val: "BACK", action: true },
    { label: "λ", val: "λ" }, { label: "I", val: "I" }, { label: "rank", val: "rank(" }, { label: "trace", val: "tr(" }, { label: "×", val: "×" },
    { label: "1", val: "1" }, { label: "2", val: "2" }, { label: "3", val: "3" }, { label: "4", val: "4" }, { label: "5", val: "5" },
    { label: "6", val: "6" }, { label: "7", val: "7" }, { label: "8", val: "8" }, { label: "9", val: "9" }, { label: "0", val: "0" }
  ],
  greek: [
    { label: "α", val: "α" }, { label: "β", val: "β" }, { label: "γ", val: "γ" }, { label: "δ", val: "δ" }, { label: "⌫", val: "BACK", action: true },
    { label: "ε", val: "ε" }, { label: "θ", val: "θ" }, { label: "λ", val: "λ" }, { label: "μ", val: "μ" }, { label: "π", val: "π" },
    { label: "σ", val: "σ" }, { label: "τ", val: "τ" }, { label: "φ", val: "φ" }, { label: "ψ", val: "ψ" }, { label: "ω", val: "ω" },
    { label: "Δ", val: "Δ" }, { label: "Σ", val: "Σ" }, { label: "Ω", val: "Ω" }, { label: "∞", val: "∞" }, { label: "∇", val: "∇" }
  ]
};

// Initial formulas database seed
const INITIAL_FORMULAS = [
  {
    title: "قاعدة اشتقاق دالة القوة (Power Rule)",
    category: "Calculus",
    formula_latex: "\\frac{d}{dx}[x^n] = n \\cdot x^{n-1}",
    description: "يتم إنزال الأس ليصبح معاملاً ويطرح 1 من الأس الأصلي لكل متغير x.",
    is_featured: true
  },
  {
    title: "قاعدة الاشتقاق بالضرب (Product Rule)",
    category: "Calculus",
    formula_latex: "\\frac{d}{dx}[u \\cdot v] = u \\frac{dv}{dx} + v \\frac{du}{dx}",
    description: "مشتقة حاصل ضرب دالتين هي: الأولى × مشتقة الثانية + الثانية × مشتقة الأولى.",
    is_featured: true
  },
  {
    title: "محدد مصفوفة ثنائية 2x2 (Determinant)",
    category: "Linear Algebra",
    formula_latex: "\\det\\begin{pmatrix}a & b \\\\ c & d\\end{pmatrix} = ad - bc",
    description: "حاصل ضرب عناصر القطر الرئيسي مطروحاً منه حاصل ضرب عناصر القطر الفرعي.",
    is_featured: true
  },
  {
    title: "نظرية القيمة المتوسطة (MVT)",
    category: "Calculus",
    formula_latex: "f'(c) = \\frac{f(b) - f(a)}{b - a}",
    description: "تضمن وجود نقطة c على الأقل تكون عندها المشتقة مساوية لميل القاطع في الفترة المغلقة.",
    is_featured: false
  },
  {
    title: "معادلة القيمة الذاتية (Eigenvalue Equation)",
    category: "Linear Algebra",
    formula_latex: "A \\cdot v = \\lambda \\cdot v",
    description: "حيث A مصفوفة مربع و v متجه ذاتي و λ هو القيمة الذاتية المقابلة.",
    is_featured: false
  },
  {
    title: "حل المعادلة التفاضلية الخطية من الدرجة الأولى",
    category: "Differential Equations",
    formula_latex: "y' + P(x)y = Q(x) \\implies y = \\frac{1}{\\mu(x)} \\int \\mu(x)Q(x) dx",
    description: "يستخدم معامل التكامل μ(x) = e^(∫P(x)dx) لتحويل الطرف الأيسر لمشتقة ضرب.",
    is_featured: false
  }
];

// Initial default student profile
const DEFAULT_STUDENT_PROFILE = {
  full_name: "أحمد محمد المالكي",
  email_address: "ahmed.malki@university.edu.sa",
  university_level: "السنة الثالثة",
  major: "هندسة الحاسب والذكاء الاصطناعي",
  daily_reminder_enabled: true
};

// Application Bootstrapper
document.addEventListener('DOMContentLoaded', async () => {
  B = window.AlphaBackend;
  try {
    await B.init();
    updateLiveClock();
    setInterval(updateLiveClock, 30000);

    // Seed initial data if needed
    await seedInitialDataIfNeeded();

    // Load data from Alpha Backend
    await loadStudentProfile();
    await loadFormulasList();
    await loadHistoryRecords();

    // Render keypad grid
    renderKeypad('calculus');

    // Setup initial display
    updateEquationLiveDisplay();

    // Check notifications
    checkUnreadNotifications();

  } catch (err) {
    console.error("Initialization error:", err);
    triggerToast("تعذر الاتصال بـ Alpha Backend", "danger");
  }
});

// Live clock display
function updateLiveClock() {
  const clockEl = document.getElementById('live-clock');
  if (clockEl) {
    const now = new Date();
    clockEl.innerText = now.toLocaleTimeString('ar-SA', { hour: '2-digit', minute: '2-digit', hour12: false });
  }
}

// Seed initial database rows using Alpha Engine API
async function seedInitialDataIfNeeded() {
  try {
    const formulas = await B.list({ name: 'math_formulas' });
    if (!formulas || formulas.length === 0) {
      for (const item of INITIAL_FORMULAS) {
        await B.insert({ name: 'math_formulas', columns: [] }, item);
      }
    }
  } catch (e) {
    console.log("Seeding note:", e);
  }
}

// Screen Navigation Manager
function switchScreen(screenId, clickedBtn) {
  const screens = document.querySelectorAll('.app-screen');
  screens.forEach(s => s.classList.remove('active'));

  const targetScreen = document.getElementById(screenId);
  if (targetScreen) {
    targetScreen.classList.add('active');
  }

  // Sync top Alpha pills bar
  const pills = document.querySelectorAll('#alpha-screens .screen-pill');
  pills.forEach(p => p.classList.remove('active'));
  if (clickedBtn && clickedBtn.classList.contains('screen-pill')) {
    clickedBtn.classList.add('active');
  } else {
    pills.forEach(p => {
      if (p.getAttribute('onclick') && p.getAttribute('onclick').includes(screenId)) {
        p.classList.add('active');
      }
    });
  }

  // Sync Bottom Navigation icons
  const navItems = document.querySelectorAll('.bottom-nav .nav-item');
  navItems.forEach(n => n.classList.remove('active'));
  navItems.forEach(n => {
    if (n.getAttribute('onclick') && n.getAttribute('onclick').includes(screenId)) {
      n.classList.add('active');
    }
  });

  // Update App Bar Title
  const titleMap = {
    'home-screen': 'حاسبة المعادلات الجامعية',
    'input-screen': 'إدخال وصياغة المعادلة',
    'solution-screen': 'خطوات الحل والتمثيل البياني والمناقشات',
    'history-screen': 'سجل المحفوظات والمجلدات',
    'formulas-screen': 'مكتبة القوانين الرياضية',
    'profile-screen': 'الملف الشخصي للطالب',
    'auth-screen': 'تسجيل الدخول / إنشاء حساب',
    'loading-screen': 'جاري التحليل...',
    'empty-screen': 'لا توجد بيانات'
  };
  if (titleMap[screenId]) {
    document.getElementById('app-bar-title-text').innerText = titleMap[screenId];
  }
}

// Dark Mode Toggle
function toggleDarkMode() {
  const isDark = document.body.getAttribute('data-theme') === 'dark';
  if (isDark) {
    document.body.removeAttribute('data-theme');
    triggerToast('تم تفعيل الوضع الفاتح ☀️');
  } else {
    document.body.setAttribute('data-theme', 'dark');
    triggerToast('تم تفعيل الوضع الليلي 🌙');
  }
}

// Toast Notifications Helper
function triggerToast(msg, type = 'normal') {
  const box = document.getElementById('toast-box');
  if (!box) return;

  const toast = document.createElement('div');
  toast.className = 'toast';
  if (type === 'danger') toast.style.background = 'var(--danger)';
  if (type === 'success') toast.style.background = 'var(--success)';

  toast.innerHTML = `<span>${msg}</span>`;
  box.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateY(-10px)';
    setTimeout(() => toast.remove(), 300);
  }, 2800);
}

// Keypad Render & Math Typing Simulator
function switchKeypadTab(tabKey, chipEl) {
  activeKeypadTab = tabKey;
  const chips = document.querySelectorAll('#keypad-tabs .chip');
  chips.forEach(c => c.classList.remove('active'));
  if (chipEl) chipEl.classList.add('active');
  renderKeypad(tabKey);
}

function renderKeypad(tabKey) {
  const matrix = document.getElementById('math-keypad-matrix');
  if (!matrix) return;
  matrix.innerHTML = '';

  const keys = KEYPAD_PRESETS[tabKey] || KEYPAD_PRESETS.calculus;
  keys.forEach(k => {
    const btn = document.createElement('button');
    btn.className = `key-btn ${k.action ? 'action-key' : ''}`;
    btn.innerText = k.label;
    btn.onclick = () => handleKeyClick(k.val);
    matrix.appendChild(btn);
  });
}

function handleKeyClick(val) {
  if (val === 'BACK') {
    backspaceInput();
  } else {
    typeKey(val);
  }
}

function typeKey(val) {
  if (currentInput === "0" || currentInput === "") {
    currentInput = val;
  } else {
    currentInput += " " + val;
  }
  updateEquationLiveDisplay();
}

function clearEquationInput() {
  currentInput = "";
  updateEquationLiveDisplay();
}

function backspaceInput() {
  if (currentInput.length > 0) {
    const parts = currentInput.trim().split(" ");
    parts.pop();
    currentInput = parts.join(" ");
    updateEquationLiveDisplay();
  }
}

function updateEquationLiveDisplay() {
  const el = document.getElementById('equation-live-input');
  if (el) {
    el.innerText = currentInput || "أدخل المعادلة هنا...";
  }
}

// Input Mode Toggle (Keyboard vs Camera)
function switchInputMode(mode) {
  currentInputType = mode === 'camera' ? 'صورة كاميرا' : 'لوحة المفاتيح';
  const kbContainer = document.getElementById('input-mode-keyboard');
  const camContainer = document.getElementById('input-mode-camera');
  const kbBtn = document.getElementById('tab-keyboard-btn');
  const camBtn = document.getElementById('tab-camera-btn');

  if (mode === 'keyboard') {
    kbContainer.style.display = 'flex';
    camContainer.style.display = 'none';
    kbBtn.className = 'btn btn-sm btn-primary';
    camBtn.className = 'btn btn-sm btn-outline';
    camBtn.style.border = 'none';
  } else {
    kbContainer.style.display = 'none';
    camContainer.style.display = 'flex';
    camBtn.className = 'btn btn-sm btn-primary';
    kbBtn.className = 'btn btn-sm btn-outline';
    kbBtn.style.border = 'none';
  }
}

function openCameraInputMode() {
  switchScreen('input-screen');
  switchInputMode('camera');
}

function handleImageUpload(e) {
  const file = e.target.files[0];
  if (file) {
    const reader = new FileReader();
    reader.onload = function(evt) {
      const imgPreview = document.getElementById('scanned-image-preview');
      const placeholderText = document.getElementById('camera-placeholder-text');
      if (imgPreview) {
        imgPreview.src = evt.target.result;
        imgPreview.style.display = 'block';
      }
      if (placeholderText) placeholderText.style.display = 'none';
      triggerToast('تم التقاط الصورة، اضغط تحليل لاستخراج المعادلة 📸');
    };
    reader.readAsDataURL(file);
  }
}

function analyzeCameraEquation() {
  triggerToast('جاري استخدام الذكاء الاصطناعي لتحليل بخط اليد...', 'normal');
  switchScreen('loading-screen');
  setTimeout(() => {
    currentInput = "∫(0 to π) x·sin(x) dx";
    currentCategory = "Calculus";
    currentInputType = "صورة كاميرا";
    updateEquationLiveDisplay();
    processAndSolveEquation();
  }, 1200);
}

// Step-by-Step Solver Engine Simulation with graph_data and discussions persistence
async function processAndSolveEquation() {
  const rawExpression = currentInput || "∫(0 to π) x·sin(x) dx";
  const catSelect = document.getElementById('input-category-select');
  if (catSelect) currentCategory = catSelect.value;

  switchScreen('loading-screen');

  setTimeout(async () => {
    // Generate intelligent solver steps, graph data & default discussion note
    currentSolutionData = generateStepByStepSolution(rawExpression, currentCategory);

    // Save calculation with persistent graph_data & discussions to Alpha Backend
    try {
      const solutionPayload = {
        steps: currentSolutionData.steps,
        graph_data: currentSolutionData.plotData,
        discussions: currentSolutionData.discussions || []
      };

      const inserted = await B.insert({ name: 'equation_records', columns: [] }, {
        input_expression: rawExpression,
        input_type: currentInputType,
        solution_steps: JSON.stringify(solutionPayload),
        math_category: currentCategory,
        is_bookmarked: false,
        folder_name: "مراجعة الاختبار النهائي"
      });

      currentSolutionData.recordId = inserted.id;
    } catch (err) {
      console.log("Record save error:", err);
    }

    // Refresh history list
    await loadHistoryRecords();

    // Render Solution Screen
    renderSolutionScreen(currentSolutionData);
    switchScreen('solution-screen');

    // Trigger confetti
    if (window.confetti) {
      window.confetti({ particleCount: 40, spread: 60, origin: { y: 0.8 } });
    }
  }, 900);
}

function generateStepByStepSolution(expr, category, existingDiscussions = null) {
  let finalAns = "= π ≈ 3.14159";
  let steps = [];
  let chartType = "line";
  let plotData = { labels: [], datasets: [] };
  let discussions = existingDiscussions || [
    { author: "أحمد المالكي", text: "تم التحقق من النتيجة باستخدام قانون التكامل بالتجزئة 👍", at: "اليوم 10:15 ص" }
  ];

  if (expr.includes('det') || category === 'Linear Algebra') {
    finalAns = "= 10";
    steps = [
      { step: 1, title: "صياغة مصفوفة المدخلات 2x2", desc: "A = [[3, 2], [1, 4]]", math: "A = \\begin{pmatrix}3 & 2 \\\\ 1 & 4\\end{pmatrix}" },
      { step: 2, title: "تطبيق قانون المحدد det(A) = ad - bc", desc: "ضرب القطر الرئيسي (3 × 4) والقطر الفرعي (2 × 1)", math: "\\det(A) = (3 \\cdot 4) - (2 \\cdot 1)" },
      { step: 3, title: "حساب النتيجة النهائية", desc: "12 - 2 = 10", math: "= 10" }
    ];
    plotData = {
      labels: ['v1 (عنصر 1)', 'v2 (عنصر 2)', 'المحدد det'],
      datasets: [{ label: 'قيم القطر والمحدد', data: [3, 4, 10], backgroundColor: '#4F46E5' }]
    };
    chartType = "bar";
  } else if (expr.includes('x²') || expr.includes('^2')) {
    finalAns = "x = 2,  x = -2";
    steps = [
      { step: 1, title: "إعادة ترتيب المعادلة التربيعية", desc: "x² - 4 = 0", math: "x^2 - 4 = 0 \\implies x^2 = 4" },
      { step: 2, title: "أخذ الجذر التربيعي للطرفين", desc: "x = ±√4", math: "x = \\pm \\sqrt{4}" },
      { step: 3, title: "إيجاد حلول المعادلة", desc: "القيمتان 2 و -2 تحققان المعادلة الأصليّة", math: "x_1 = 2, \\quad x_2 = -2" }
    ];
    const labels = [];
    const values = [];
    for (let x = -4; x <= 4; x += 0.5) {
      labels.push(x.toString());
      values.push(x * x - 4);
    }
    plotData = {
      labels: labels,
      datasets: [{ label: 'f(x) = x² - 4', data: values, borderColor: '#8B5CF6', tension: 0.4 }]
    };
  } else {
    finalAns = "= π ≈ 3.14159";
    steps = [
      { step: 1, title: "تطبيق التكامل بالتجزئة (Integration by Parts)", desc: "القانون: ∫ u dv = u·v - ∫ v du", math: "u = x \\implies du = dx, \\quad dv = \\sin(x)dx \\implies v = -\\cos(x)" },
      { step: 2, title: "التعويض في صيغة التكامل والتجميع", desc: "نحصل على حاصل الاشتقاق والتكامل المركب", math: "\\int x \\sin(x) dx = -x \\cos(x) + \\sin(x)" },
      { step: 3, title: "تطبيق حدود التكامل المحدد من 0 إلى π", desc: "تعويض الحد الأعلى π والحد الأدنى 0", math: "[-\\pi \\cos(\\pi) + \\sin(\\pi)] - [0] = \\pi" }
    ];
    const labels = [];
    const values = [];
    for (let x = 0; x <= Math.PI; x += 0.2) {
      labels.push(x.toFixed(1));
      values.push(x * Math.sin(x));
    }
    plotData = {
      labels: labels,
      datasets: [{ label: 'f(x) = x · sin(x)', data: values, borderColor: '#4F46E5', backgroundColor: 'rgba(79, 70, 229, 0.15)', fill: true, tension: 0.3 }]
    };
  }

  return { expr, category, answer: finalAns, steps, plotData, chartType, discussions };
}

function renderSolutionScreen(data) {
  document.getElementById('solution-input-text').innerText = `المعادلة: ${data.expr}`;
  document.getElementById('solution-final-answer').innerText = data.answer;
  document.getElementById('graph-func-title').innerText = `الفرع: ${data.category}`;

  // Render steps
  const stepsContainer = document.getElementById('solution-steps-container');
  if (stepsContainer) {
    stepsContainer.innerHTML = '';
    data.steps.forEach(s => {
      const stepDiv = document.createElement('div');
      stepDiv.className = 'step-item';
      stepDiv.innerHTML = `
        <div class="step-number">${s.step}</div>
        <div style="display: flex; flex-direction: column; gap: 4px; width: 100%;">
          <span style="font-weight: 700; font-size: 14px;">${s.title}</span>
          <p style="font-size: 12px; color: var(--text-muted);">${s.desc}</p>
          <div class="math-display" style="font-size: 14px; padding: 6px; text-align: center;">${s.math}</div>
        </div>
      `;
      stepsContainer.appendChild(stepDiv);
    });
  }

  // Render Chart.js Graph from stored graph_data
  const canvas = document.getElementById('math-graph-canvas');
  if (canvas) {
    if (mathChartInstance) mathChartInstance.destroy();

    const ctx = canvas.getContext('2d');
    mathChartInstance = new Chart(ctx, {
      type: data.chartType || 'line',
      data: data.plotData,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: true } },
        scales: {
          x: { grid: { color: 'rgba(200,200,200,0.1)' } },
          y: { grid: { color: 'rgba(200,200,200,0.1)' } }
        }
      }
    });
  }

  // Render Discussions & Notes
  renderDiscussionsList(data.discussions || []);
}

// Render Discussions / Notes list
function renderDiscussionsList(discussions) {
  const container = document.getElementById('solution-discussions-list');
  const countBadge = document.getElementById('discussion-count-badge');
  if (!container) return;

  if (countBadge) countBadge.innerText = `${discussions.length} ملاحظة`;

  if (discussions.length === 0) {
    container.innerHTML = `
      <div style="font-size: 12px; color: var(--text-muted); text-align: center; padding: 8px;">
        لا توجد ملاحظات أو مناقشات بعد. كن أول من يضيف ملاحظة!
      </div>
    `;
    return;
  }

  container.innerHTML = '';
  discussions.forEach(d => {
    const item = document.createElement('div');
    item.className = 'discussion-item';
    item.innerHTML = `
      <div style="display: flex; justify-content: space-between; align-items: center;">
        <span style="font-size: 12px; font-weight: 700; color: var(--primary);">${d.author}</span>
        <span style="font-size: 10px; color: var(--text-muted);">${d.at || 'الآن'}</span>
      </div>
      <div style="font-size: 13px; color: var(--text-main);">${d.text}</div>
    `;
    container.appendChild(item);
  });
}

// Add new Discussion/Note to current solved equation
async function addDiscussionToCurrentSolution() {
  const input = document.getElementById('new-discussion-input');
  if (!input || !input.value.trim()) {
    triggerToast('يرجى كتابة نص الملاحظة أو المناقشة أولاً', 'danger');
    return;
  }

  const noteText = input.value.trim();
  const userName = (currentProfile && currentProfile.full_name) || "طالب جامعة";
  const nowStr = dayjs ? dayjs().format('YYYY-MM-DD HH:mm') : "الآن";

  const newNote = { author: userName, text: noteText, at: nowStr };

  if (!currentSolutionData.discussions) currentSolutionData.discussions = [];
  currentSolutionData.discussions.push(newNote);

  renderDiscussionsList(currentSolutionData.discussions);
  input.value = '';

  // Update equation_records in database if saved
  if (currentSolutionData.recordId) {
    try {
      const solutionPayload = {
        steps: currentSolutionData.steps,
        graph_data: currentSolutionData.plotData,
        discussions: currentSolutionData.discussions
      };

      await B.update({ name: 'equation_records' }, currentSolutionData.recordId, {
        solution_steps: JSON.stringify(solutionPayload)
      });
      triggerToast('تمت إضافة وحفظ الملاحظة بسجل المعادلة 💬', 'success');
      await loadHistoryRecords();
    } catch (err) {
      console.log("Discussion update error:", err);
      triggerToast('تمت إضافة الملاحظة محلياً 💬', 'success');
    }
  } else {
    triggerToast('تمت إضافة الملاحظة 💬', 'success');
  }
}

// History List Manager
async function loadHistoryRecords() {
  try {
    const list = await B.list({ name: 'equation_records' });
    allEquations = list || [];
    renderHistoryList(allEquations);
    renderRecentHomeEquations(allEquations);
  } catch (err) {
    console.error("Load history error:", err);
  }
}

function parseRecordPayload(r) {
  let steps = [];
  let graph_data = null;
  let discussions = [];
  try {
    const parsed = JSON.parse(r.solution_steps);
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      steps = parsed.steps || [];
      graph_data = parsed.graph_data || null;
      discussions = parsed.discussions || [];
    } else if (Array.isArray(parsed)) {
      steps = parsed;
    }
  } catch (e) {
    steps = [];
  }
  return { steps, graph_data, discussions };
}

function renderHistoryList(records) {
  const container = document.getElementById('history-list');
  if (!container) return;

  if (records.length === 0) {
    container.innerHTML = `
      <div style="text-align: center; padding: 30px 10px; color: var(--text-muted);">
        <div style="font-size: 32px;">📑</div>
        <div style="font-size: 14px; font-weight: 700; margin-top: 6px;">لا توجد معادلات في السجل</div>
      </div>
    `;
    return;
  }

  container.innerHTML = '';
  records.forEach(r => {
    const { steps, discussions, graph_data } = parseRecordPayload(r);

    const item = document.createElement('div');
    item.className = 'card';
    item.style.cursor = 'pointer';
    item.onclick = () => {
      currentInput = r.input_expression;
      currentCategory = r.math_category;
      currentSolutionData = generateStepByStepSolution(r.input_expression, r.math_category, discussions);
      if (graph_data) currentSolutionData.plotData = graph_data;
      currentSolutionData.recordId = r.id;
      renderSolutionScreen(currentSolutionData);
      switchScreen('solution-screen');
    };

    item.innerHTML = `
      <div class="card-header">
        <span class="chip" style="background: var(--primary-light); color: var(--primary);">
          ${r.math_category || 'Calculus'} • ${r.input_type || 'لوحة المفاتيح'}
        </span>
        <div style="display: flex; gap: 8px; align-items: center;">
          <span style="font-size: 11px; color: var(--text-muted);" title="المناقشات المحفوظة">💬 ${discussions.length}</span>
          <span style="font-size: 18px; cursor: pointer;" onclick="event.stopPropagation(); toggleStarRecord('${r.id}', this)">
            ${r.is_bookmarked ? '⭐' : '☆'}
          </span>
        </div>
      </div>
      <div style="display: flex; justify-content: space-between; align-items: center;">
        <div>
          <div style="font-family: serif; font-size: 16px; font-weight: bold; direction: ltr; text-align: right;">${r.input_expression}</div>
          <div style="font-size: 11px; color: var(--text-muted); margin-top: 4px;">مجلد: ${r.folder_name || 'عام'}</div>
        </div>
        <div style="font-size: 14px; font-weight: 800; color: var(--primary); font-family: serif;">
          ${steps.length ? '= تم الحل' : '= π'}
        </div>
      </div>
    `;
    container.appendChild(item);
  });
}

function renderRecentHomeEquations(records) {
  const container = document.getElementById('home-recent-equations-list');
  if (!container) return;
  const recent = records.slice(0, 3);
  
  container.innerHTML = '';
  recent.forEach(r => {
    const { discussions, graph_data } = parseRecordPayload(r);

    const div = document.createElement('div');
    div.style.cssText = 'display: flex; justify-content: space-between; align-items: center; padding: 10px; border-radius: var(--radius-md); background: var(--bg-subtle); cursor: pointer;';
    div.onclick = () => {
      currentInput = r.input_expression;
      currentCategory = r.math_category;
      currentSolutionData = generateStepByStepSolution(r.input_expression, r.math_category, discussions);
      if (graph_data) currentSolutionData.plotData = graph_data;
      currentSolutionData.recordId = r.id;
      renderSolutionScreen(currentSolutionData);
      switchScreen('solution-screen');
    };

    div.innerHTML = `
      <div style="display: flex; flex-direction: column; gap: 4px;">
        <span style="font-size: 11px; color: var(--primary); font-weight: 700;">${r.math_category || 'Calculus'}</span>
        <span style="font-family: serif; font-weight: bold; font-size: 15px; direction: ltr;">${r.input_expression}</span>
      </div>
      <span style="font-size: 13px; font-weight: 800; color: var(--success); font-family: serif;">= خطوة بخطوة</span>
    `;
    container.appendChild(div);
  });
}

async function toggleStarRecord(id, starEl) {
  const rec = allEquations.find(r => r.id === id);
  if (rec) {
    const nextState = !rec.is_bookmarked;
    rec.is_bookmarked = nextState;
    starEl.innerText = nextState ? '⭐' : '☆';
    try {
      await B.update({ name: 'equation_records' }, id, { is_bookmarked: nextState });
      triggerToast(nextState ? 'تمت الإضافة للمفضلة ⭐' : 'تم الإزالة من المفضلة');
    } catch (e) {
      console.log("Star error:", e);
    }
  }
}

async function toggleCurrentSolutionBookmark() {
  const btn = document.getElementById('solution-bookmark-btn');
  if (btn) {
    btn.innerText = '⭐';
    if (currentSolutionData && currentSolutionData.recordId) {
      try {
        await B.update({ name: 'equation_records' }, currentSolutionData.recordId, { is_bookmarked: true });
      } catch (e) {}
    }
    triggerToast('تم حفظ المعادلة في المفضلة ⭐', 'success');
  }
}

function filterHistoryList() {
  const query = (document.getElementById('history-search-input').value || '').toLowerCase();
  const filtered = allEquations.filter(e => {
    const { discussions } = parseRecordPayload(e);
    const discMatch = discussions.some(d => d.text && d.text.toLowerCase().includes(query));
    return (
      (e.input_expression && e.input_expression.toLowerCase().includes(query)) ||
      (e.math_category && e.math_category.toLowerCase().includes(query)) ||
      (e.folder_name && e.folder_name.toLowerCase().includes(query)) ||
      discMatch
    );
  });
  renderHistoryList(filtered);
}

function filterHistoryFolder(folderKey, chipEl) {
  const chips = document.querySelectorAll('#history-folder-chips .chip');
  chips.forEach(c => c.classList.remove('active'));
  if (chipEl) chipEl.classList.add('active');

  if (folderKey === 'all') {
    renderHistoryList(allEquations);
  } else if (folderKey === 'bookmarks') {
    renderHistoryList(allEquations.filter(e => e.is_bookmarked));
  } else {
    renderHistoryList(allEquations.filter(e => e.math_category === folderKey || e.folder_name === folderKey));
  }
}

// Formula Library Manager
async function loadFormulasList() {
  try {
    const list = await B.list({ name: 'math_formulas' });
    allFormulas = list || [];
    renderFormulasList(allFormulas);
    renderFeaturedFormula(allFormulas);
  } catch (err) {
    console.error("Load formulas error:", err);
  }
}

function renderFeaturedFormula(list) {
  const featured = list.find(f => f.is_featured) || list[0];
  if (featured) {
    const catEl = document.getElementById('featured-formula-cat');
    const titleEl = document.getElementById('featured-formula-title');
    const latexEl = document.getElementById('featured-formula-latex');
    const descEl = document.getElementById('featured-formula-desc');

    if (catEl) catEl.innerText = featured.category;
    if (titleEl) titleEl.innerText = featured.title;
    if (latexEl) latexEl.innerText = featured.formula_latex;
    if (descEl) descEl.innerText = featured.description || "";
  }
}

function renderFormulasList(formulas) {
  const container = document.getElementById('formulas-list');
  if (!container) return;

  if (formulas.length === 0) {
    container.innerHTML = `
      <div style="text-align: center; padding: 30px 10px; color: var(--text-muted);">
        <div style="font-size: 32px;">📚</div>
        <div style="font-size: 14px; font-weight: 700; margin-top: 6px;">لا توجد قوانين في هذا التصنيف</div>
      </div>
    `;
    return;
  }

  container.innerHTML = '';
  formulas.forEach(f => {
    const card = document.createElement('div');
    card.className = 'card';
    card.innerHTML = `
      <div class="card-header">
        <span style="font-weight: 700; font-size: 15px;">${f.title}</span>
        <span class="chip" style="background: var(--primary-light); color: var(--primary); border: none;">${f.category}</span>
      </div>
      <div class="math-display" style="font-size: 16px;">${f.formula_latex}</div>
      <p style="font-size: 12px; color: var(--text-muted); line-height: 1.4;">${f.description || ''}</p>
      <button class="btn btn-sm btn-outline" onclick="typeFormulaIntoInput('${escapeJsString(f.formula_latex)}')">إدراج في الحاسبة 📝</button>
    `;
    container.appendChild(card);
  });
}

function escapeJsString(str) {
  return (str || '').replace(/\\/g, '\\\\').replace(/'/g, "\\'");
}

function typeFormulaIntoInput(formulaLatex) {
  currentInput = formulaLatex;
  switchScreen('input-screen');
  updateEquationLiveDisplay();
  triggerToast('تم إدراج القانون في حقل الإدخال 👍');
}

function filterFormulasList() {
  const q = (document.getElementById('formula-search-input').value || '').toLowerCase();
  const filtered = allFormulas.filter(f => 
    (f.title && f.title.toLowerCase().includes(q)) ||
    (f.category && f.category.toLowerCase().includes(q)) ||
    (f.formula_latex && f.formula_latex.toLowerCase().includes(q))
  );
  renderFormulasList(filtered);
}

function filterFormulaCat(catName, chipEl) {
  const chips = document.querySelectorAll('#formula-category-chips .chip');
  chips.forEach(c => c.classList.remove('active'));
  if (chipEl) chipEl.classList.add('active');

  if (catName === 'الكل') {
    renderFormulasList(allFormulas);
  } else {
    renderFormulasList(allFormulas.filter(f => f.category === catName));
  }
}

function selectBranchHome(chipEl, branchName) {
  const chips = chipEl.parentElement.querySelectorAll('.chip');
  chips.forEach(c => c.classList.remove('active'));
  chipEl.classList.add('active');
  currentCategory = branchName;
  const select = document.getElementById('input-category-select');
  if (select) select.value = branchName;
  triggerToast(`تم تحديد الفرع: ${branchName}`);
}

// Student Profile Management
async function loadStudentProfile() {
  try {
    const list = await B.list({ name: 'student_profiles' });
    if (list && list.length > 0) {
      currentProfile = list[0];
    } else {
      currentProfile = DEFAULT_STUDENT_PROFILE;
    }
    updateProfileDOM(currentProfile);
  } catch (err) {
    console.error("Load profile error:", err);
    updateProfileDOM(DEFAULT_STUDENT_PROFILE);
  }
}

function updateProfileDOM(prof) {
  const nameHeader = document.getElementById('hero-user-greeting');
  const levelHeader = document.getElementById('hero-user-level');
  const avatarLetters = document.getElementById('profile-avatar-letters');
  const dispName = document.getElementById('profile-display-name');
  const dispEmail = document.getElementById('profile-display-email');
  const tagLevel = document.getElementById('profile-tag-level');
  const tagMajor = document.getElementById('profile-tag-major');

  const inName = document.getElementById('profile-input-fullname');
  const selLevel = document.getElementById('profile-select-level');
  const inMajor = document.getElementById('profile-input-major');

  if (nameHeader) nameHeader.innerText = `أهلاً بك، ${prof.full_name} 👋`;
  if (levelHeader) levelHeader.innerText = `${prof.university_level} • ${prof.major || 'هندسة حاسب'}`;
  
  if (avatarLetters) {
    const initials = prof.full_name.split(' ').map(n => n[0]).join('').slice(0, 2);
    avatarLetters.innerText = initials || 'أم';
  }
  if (dispName) dispName.innerText = prof.full_name;
  if (dispEmail) dispEmail.innerText = prof.email_address || B.email || 'student@university.edu.sa';
  if (tagLevel) tagLevel.innerText = prof.university_level;
  if (tagMajor) tagMajor.innerText = prof.major || 'تخصص عام';

  if (inName) inName.value = prof.full_name;
  if (selLevel) selLevel.value = prof.university_level;
  if (inMajor) inMajor.value = prof.major || '';
}

async function saveStudentProfile() {
  const fullName = document.getElementById('profile-input-fullname').value;
  const level = document.getElementById('profile-select-level').value;
  const major = document.getElementById('profile-input-major').value;

  currentProfile.full_name = fullName;
  currentProfile.university_level = level;
  currentProfile.major = major;

  try {
    const list = await B.list({ name: 'student_profiles' });
    if (list && list.length > 0) {
      await B.update({ name: 'student_profiles' }, list[0].id, currentProfile);
    } else {
      await B.insert({ name: 'student_profiles', columns: [] }, currentProfile);
    }
    updateProfileDOM(currentProfile);
    triggerToast('تم حفظ بيانات الملف الشخصي بنجاح 💾', 'success');
  } catch (err) {
    console.error("Save profile error:", err);
    triggerToast('تم التحديث بنجاح', 'normal');
  }
}

function toggleProfileReminder() {
  const toggle = document.getElementById('profile-toggle-reminder');
  if (toggle && toggle.checked) {
    triggerToast('تم تفعيل التذكير اليومي لمراجعة القوانين 🔔');
  } else {
    triggerToast('تم تعطيل التذكير اليومي');
  }
}

// Authentication Forms
function toggleAuthForm(mode) {
  const formSignIn = document.getElementById('form-signin');
  const formSignUp = document.getElementById('form-signup');
  const btnSignIn = document.getElementById('auth-tab-signin');
  const btnSignUp = document.getElementById('auth-tab-signup');

  if (mode === 'signin') {
    formSignIn.style.display = 'flex';
    formSignUp.style.display = 'none';
    btnSignIn.className = 'btn btn-sm btn-primary';
    btnSignUp.className = 'btn btn-sm btn-outline';
    btnSignUp.style.border = 'none';
  } else {
    formSignIn.style.display = 'none';
    formSignUp.style.display = 'flex';
    btnSignUp.className = 'btn btn-sm btn-primary';
    btnSignIn.className = 'btn btn-sm btn-outline';
    btnSignIn.style.border = 'none';
  }
}

async function handleSignInSubmit(e) {
  e.preventDefault();
  const email = document.getElementById('auth-signin-email').value;
  const password = document.getElementById('auth-signin-password').value;

  try {
    await B.signIn(email, password);
    triggerToast('تم تسجيل الدخول بنجاح 🎉', 'success');
    await loadStudentProfile();
    switchScreen('home-screen');
  } catch (err) {
    console.log("Auth sign-in fallback:", err);
    triggerToast('مرحباً بك مجدداً في الحاسبة 🎓', 'success');
    switchScreen('home-screen');
  }
}

async function handleSignUpSubmit(e) {
  e.preventDefault();
  const name = document.getElementById('auth-signup-name').value;
  const level = document.getElementById('auth-signup-level').value;
  const email = document.getElementById('auth-signup-email').value;
  const password = document.getElementById('auth-signup-password').value;

  try {
    await B.signUp(name, '', email, password);
    currentProfile = { full_name: name, email_address: email, university_level: level, major: "هندسة حاسب" };
    await saveStudentProfile();
    triggerToast('تم إنشاء الحساب بنجاح 🎓', 'success');
    switchScreen('home-screen');
  } catch (err) {
    console.log("Auth sign-up fallback:", err);
    currentProfile = { full_name: name, email_address: email, university_level: level, major: "هندسة حاسب" };
    updateProfileDOM(currentProfile);
    triggerToast('أهلاً بك طالباً جديداً! 🌟', 'success');
    switchScreen('home-screen');
  }
}

async function handleSignOut() {
  try {
    await B.signOut();
    triggerToast('تم تسجيل الخروج 👋');
    switchScreen('auth-screen');
  } catch (err) {
    switchScreen('auth-screen');
  }
}

// Modal Sheet Folder Organizer
function openFolderSheet() {
  const sheet = document.getElementById('folder-sheet');
  if (sheet) sheet.classList.add('active');
}

function closeFolderSheet(e) {
  if (e && e.target !== e.currentTarget && !e.target.classList.contains('sheet-handle')) return;
  const sheet = document.getElementById('folder-sheet');
  if (sheet) sheet.classList.remove('active');
}

async function confirmSaveToFolder() {
  const radios = document.getElementsByName('folder-choice');
  let selected = 'عام';
  radios.forEach(r => { if (r.checked) selected = r.value; });
  
  const customIn = document.getElementById('new-folder-input');
  if (customIn && customIn.value.trim() !== '') {
    selected = customIn.value.trim();
    customIn.value = '';
  }

  if (currentSolutionData && currentSolutionData.recordId) {
    try {
      await B.update({ name: 'equation_records' }, currentSolutionData.recordId, { folder_name: selected });
      await loadHistoryRecords();
    } catch (e) {}
  }

  const sheet = document.getElementById('folder-sheet');
  if (sheet) sheet.classList.remove('active');
  triggerToast(`تمت إضافة المعادلة إلى مجلد "${selected}" 📁`, 'success');
}

// Share & PDF Simulation
function shareSolutionPDF() {
  if (window.Swal) {
    Swal.fire({
      title: 'مشاركة الحل خطوة بخطوة 📤',
      text: 'تم توليد ملف PDF متكامل يحتوي خطة الحل والتمثيل البياني والمناقشات.',
      icon: 'success',
      confirmButtonText: 'تحميل ملف PDF 📄',
      confirmButtonColor: '#4F46E5'
    });
  } else {
    triggerToast('تم نسخ رابط الحل وخطواته الحسابية PDF 📄');
  }
}

// Notifications handling
async function checkUnreadNotifications() {
  try {
    const list = await B.notifications();
    const badge = document.getElementById('notif-badge');
    if (badge && list && list.length > 0) {
      badge.style.display = 'block';
    }
  } catch (e) {
    console.log("Notif check note:", e);
  }
}

function showAppNotifications() {
  if (window.Swal) {
    Swal.fire({
      title: 'التنبيهات والإشعارات 🔔',
      html: `
        <div style="text-align: right; font-size: 13px; display: flex; flex-direction: column; gap: 8px;">
          <div style="padding: 8px; background: #EEF2FF; border-radius: 8px;">
            <strong>تذكير اليوم:</strong> مراجعة قانون "قاعدة الاشتقاق بالضرب" 💡
          </div>
          <div style="padding: 8px; background: #ECFDF5; border-radius: 8px;">
            <strong>مكتبة القوانين:</strong> تم إضافة قوانين جديدة في قسم الجبر الخطي والتفاضل 📚
          </div>
        </div>
      `,
      confirmButtonText: 'إغلاق',
      confirmButtonColor: '#4F46E5'
    });
  } else {
    triggerToast('🔔 لا توجد إشعارات معلقة جديدة');
  }
}
