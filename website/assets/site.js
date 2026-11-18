const menu = document.querySelector('.mobile-menu');
menu.addEventListener('keydown', event => {
  if (event.key === 'Escape' && menu.open) {
    menu.open = false;
    menu.querySelector('summary').focus();
  }
});
document.addEventListener('click', event => {
  if (menu.open && !menu.contains(event.target)) menu.open = false;
});

for (const recording of document.querySelectorAll('[data-recording]')) {
  const button = recording.querySelector('button');
  const picture = recording.querySelector('img');
  const label = button.querySelector('span');
  const poster = picture.src;
  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');

  function setPlaying(playing) {
    picture.src = playing ? recording.dataset.src : poster;
    button.setAttribute('aria-pressed', String(playing));
    label.textContent = playing ? 'Stop connection demo' : 'Play connection demo';
  }

  button.hidden = false;
  button.addEventListener('click', () => setPlaying(button.getAttribute('aria-pressed') !== 'true'));
  reducedMotion.addEventListener('change', ({ matches }) => {
    if (matches && button.getAttribute('aria-pressed') === 'true') setPlaying(false);
  });
}

if (navigator.clipboard) {
  for (const code of document.querySelectorAll('.prose pre > code.language-sh')) {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'code-copy';
    button.textContent = 'Copy command';
    button.setAttribute('aria-live', 'polite');
    code.parentElement.after(button);
    let reset;
    button.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(code.textContent.trim());
        button.textContent = 'Copied';
      } catch {
        button.textContent = 'Select the text to copy';
      }
      clearTimeout(reset);
      reset = setTimeout(() => { button.textContent = 'Copy command'; }, 2400);
    });
  }
}

const calm = matchMedia('(prefers-reduced-motion: reduce)');

// Screen tour: tabs, autoplay while visible, and an enlarge lightbox.
const tour = document.querySelector('[data-tour]');
if (tour) {
  const tabs = [...tour.querySelectorAll('[role="tab"]')];
  const shots = [...tour.querySelectorAll('.tour-screen img')];
  const copies = [...tour.querySelectorAll('.tour-copy article')];
  const dialog = tour.querySelector('.lightbox');
  const zoomed = dialog.querySelector('img');
  let index = 0;

  const select = (next, focus = false) => {
    index = (next + tabs.length) % tabs.length;
    const id = tabs[index].dataset.screen;
    tabs.forEach(tab => tab.setAttribute('aria-selected', String(tab.dataset.screen === id)));
    shots.forEach(shot => shot.classList.toggle('is-active', shot.dataset.screen === id));
    copies.forEach(copy => { copy.hidden = copy.dataset.screen !== id; });
    if (focus) tabs[index].focus();
  };
  const stopAutoplay = () => tour.classList.remove('is-playing');

  tabs.forEach((tab, position) => {
    tab.tabIndex = position ? -1 : 0;
    tab.addEventListener('click', () => { stopAutoplay(); select(position); });
    tab.querySelector('i').addEventListener('animationend', () => {
      if (tour.classList.contains('is-playing')) select(index + 1);
    });
  });
  tour.querySelector('[role="tablist"]').addEventListener('keydown', event => {
    const move = { ArrowRight: 1, ArrowLeft: -1 }[event.key];
    if (!move) return;
    event.preventDefault();
    stopAutoplay();
    select(index + move, true);
    tabs.forEach((tab, position) => { tab.tabIndex = position === index ? 0 : -1; });
  });

  if (!calm.matches) {
    new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting && !tour.dataset.touched) tour.classList.add('is-playing');
      else stopAutoplay();
    }, { threshold: 0.3 }).observe(tour);
    tour.addEventListener('pointerdown', () => { tour.dataset.touched = ''; });
  }

  tour.querySelector('.tour-screen').addEventListener('click', () => {
    stopAutoplay();
    tour.dataset.touched = '';
    const shot = shots[index];
    zoomed.src = shot.currentSrc || shot.src;
    zoomed.alt = shot.alt;
    dialog.showModal();
  });
  dialog.addEventListener('click', event => {
    if (event.target === dialog) dialog.close();
  });
}
