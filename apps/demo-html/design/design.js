window.AlphaDesign = {
  onRender: function (ctx) {
    try {
      var root = ctx.root || document;
      if (window.gsap) {
        var items = Array.prototype.filter.call(root.querySelectorAll(".tile, .feat, #rows .card"), function (el) { return !el.dataset.ai; });
        items.forEach(function (el) { el.dataset.ai = 1; });
        if (items.length) gsap.from(items, { y: 24, opacity: 0, duration: 0.6, stagger: 0.06, ease: "power3.out" });
      }
      if (window.VanillaTilt) {
        root.querySelectorAll(".feat:not([data-tilt-on])").forEach(function (el) { el.setAttribute("data-tilt-on", 1); VanillaTilt.init(el, { max: 8, glare: true, "max-glare": 0.2 }); });
      }
    } catch (e) { console.warn(e); }
  }
};
