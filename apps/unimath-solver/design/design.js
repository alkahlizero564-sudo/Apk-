// Math Solver - Custom Spatial Motion Engine
(function() {
  window.AlphaDesign = {
    onRender({ screen, root }) {
      try {
        if (!root) return;

        // 1. Entrance Staggering Animation for Grid Tiles & Cards
        const cards = root.querySelectorAll('.card, .tile, .row');
        if (cards.length > 0 && typeof gsap !== 'undefined') {
          gsap.fromTo(cards, 
            { opacity: 0, y: 16, scale: 0.98 },
            { opacity: 1, y: 0, scale: 1, duration: 0.4, stagger: 0.05, ease: 'power2.out' }
          );
        }

        // 2. Interactive Tilt effect on Bento tiles using VanillaTilt (if available)
        if (typeof VanillaTilt !== 'undefined') {
          const bentoTiles = root.querySelectorAll('.card.tile');
          bentoTiles.forEach(tile => {
            if (!tile.dataset.aiTilt) {
              tile.dataset.aiTilt = '1';
              VanillaTilt.init(tile, {
                max: 8,
                speed: 400,
                glare: true,
                "max-glare": 0.15
              });
            }
          });
        }

        // 3. Confetti feedback on solving/saving equations
        const saveBtns = root.querySelectorAll('.btn, #add, .fab');
        saveBtns.forEach(btn => {
          if (!btn.dataset.aiConfetti) {
            btn.dataset.aiConfetti = '1';
            btn.addEventListener('click', (e) => {
              if (typeof confetti === 'function') {
                confetti({
                  particleCount: 35,
                  spread: 60,
                  origin: { y: 0.8 },
                  colors: ['#3B82F6', '#8B5CF6', '#06B6D4', '#10B981']
                });
              }
            });
          }
        });

        // 4. Subtle Formula Typing Effect on Hero Title (if Typed is present)
        const heroTitle = root.querySelector('.hero h1');
        if (heroTitle && !heroTitle.dataset.aiTyped && typeof Typed !== 'undefined') {
          heroTitle.dataset.aiTyped = '1';
          const originalText = heroTitle.textContent;
          heroTitle.textContent = '';
          new Typed(heroTitle, {
            strings: [originalText, 'حل المعادلات والتعويضات بخطوات مفصلة'],
            typeSpeed: 40,
            backSpeed: 25,
            backDelay: 4000,
            loop: true
          });
        }

      } catch (err) {
        console.warn('AlphaDesign render hook:', err);
      }
    }
  };
})();
