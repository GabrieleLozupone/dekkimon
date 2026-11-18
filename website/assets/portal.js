import { makeRenderer } from './globe-renderer.js';

const panel = document.querySelector('[data-portal]');
const display = panel.querySelector('.portal-stage');
const canvas = panel.querySelector('canvas');
const status = panel.querySelector('[role="status"]');
const motion = panel.querySelector('.motion-button');
const connect = document.querySelector('.connect-button');
const label = connect.querySelector('span');
const menuButton = document.querySelector('.menu-button');
const menuLabel = menuButton.querySelector('span:last-child');
const disconnect = document.querySelector('.disconnect-button');
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');

const scene = { time: 0, spin: 0.6, pulse: 1.1, energy: 0, reveal: 0 };
let draw;
let raf = 0;
let last = 0;
let connecting = false;
let elapsed = 0;
let connected = false;
let paused = false;
let visible = true;
let menuOpen = false;

function setStep(step) {
  panel.dataset.step = step;
  connect.hidden = step !== 'connect';
  menuButton.hidden = disconnect.hidden = step === 'connect';
}

function setMenu(open) {
  menuOpen = open;
  panel.toggleAttribute('data-menu', open);
  menuButton.setAttribute('aria-pressed', String(open));
  menuLabel.textContent = open ? 'Return to game' : 'Open quick menu';
  status.textContent = open ? 'Quick menu: check Wi-Fi, picture and sound' : 'Streaming. Open the quick menu with R4';
  setStep(open ? 'menu' : 'play');
}

function isRunning() {
  return draw && !connected && !paused && !reducedMotion.matches && !document.hidden && visible;
}

function schedule() {
  if (!isRunning()) {
    cancelAnimationFrame(raf);
    raf = 0;
    last = 0;
  } else if (!raf) {
    raf = requestAnimationFrame(tick);
  }
}

function resize() {
  const { clientWidth, clientHeight } = display;
  if (!draw || !clientWidth || !clientHeight) return;
  const scale = Math.min(devicePixelRatio, 1.5, 960 / clientWidth);
  canvas.width = Math.round(clientWidth * scale);
  canvas.height = Math.round(clientHeight * scale);
  draw(scene);
}

function configureMotion() {
  motion.hidden = !draw || reducedMotion.matches || connected;
  motion.toggleAttribute('data-paused', paused);
  motion.setAttribute('aria-label', paused ? 'Resume portal animation' : 'Pause portal animation');
  panel.toggleAttribute('data-webgl', Boolean(draw) && !reducedMotion.matches);
  canvas.hidden = !draw || reducedMotion.matches;
  schedule();
}

function init() {
  if (reducedMotion.matches) return;
  try {
    draw = makeRenderer(canvas);
    resize();
  } catch {
    draw = null;
  }
  configureMotion();
}

function setConnected(value) {
  connected = value;
  menuOpen = false;
  panel.removeAttribute('data-menu');
  panel.style.removeProperty('--energy');
  connecting = false;
  panel.removeAttribute('data-connecting');
  panel.removeAttribute('data-opening');
  panel.toggleAttribute('data-connected', value);
  connect.removeAttribute('aria-disabled');
  if (value) {
    setMenu(false);
    requestAnimationFrame(() => menuButton.focus({ preventScroll: true }));
  } else {
    setStep('connect');
    scene.energy = 0;
    scene.reveal = 0;
    status.textContent = 'Try it: connect to the demo PS5';
    label.textContent = 'Connect';
    draw?.(scene);
  }
  configureMotion();
}

function tick(now) {
  raf = 0;
  if (!isRunning()) return;
  const interval = connecting ? 15 : 31;
  if (!last || now - last >= interval) {
    const step = last ? Math.min((now - last) / 1000, 0.1) : interval / 1000;
    last = now;
    if (connecting) {
      elapsed += step;
      const charge = Math.min(elapsed / 0.9, 1);
      scene.energy = (1 - Math.cos(charge * Math.PI)) / 2;
      const opening = Math.max(0, (elapsed - 1.25) / 1.15);
      if (opening >= 1) {
        setConnected(true);
        return;
      }
      if (opening > 0 && !panel.hasAttribute('data-opening')) {
        panel.setAttribute('data-opening', '');
        status.textContent = 'Starting Remote Play…';
      }
      scene.reveal = opening ** 4;
      panel.style.setProperty('--energy', scene.energy.toFixed(3));
    }
    scene.time += step;
    scene.spin += step * (0.07 + scene.energy * 0.65);
    scene.pulse += step * (1.9 + scene.energy * 2.9);
    draw(scene);
  }
  schedule();
}

function startConnection() {
  if (connecting) return;
  if (!draw || paused || reducedMotion.matches) {
    setConnected(true);
    return;
  }
  connecting = true;
  panel.setAttribute('data-connecting', '');
  elapsed = 0;
  status.textContent = 'Connecting to “Living room PS5”…';
  connect.setAttribute('aria-disabled', 'true');
  schedule();
}

setStep('connect');
connect.addEventListener('click', startConnection);
menuButton.addEventListener('click', () => setMenu(!menuOpen));
disconnect.addEventListener('click', () => {
  setConnected(false);
  connect.focus({ preventScroll: true });
});
display.addEventListener('click', event => {
  if (!connected && !connecting && event.target.closest('[data-connect-target]')) startConnection();
  else if (connected) setMenu(!menuOpen);
});

motion.addEventListener('click', () => {
  paused = !paused;
  if (paused && connecting) setConnected(true);
  configureMotion();
});

canvas.addEventListener('webglcontextlost', event => {
  event.preventDefault();
  draw = null;
  if (connecting) setConnected(true);
  configureMotion();
});
canvas.addEventListener('webglcontextrestored', init);
reducedMotion.addEventListener('change', ({ matches }) => {
  if (matches && connecting) setConnected(true);
  if (!matches && !draw) init();
  configureMotion();
});
document.addEventListener('visibilitychange', schedule);
new ResizeObserver(resize).observe(display);
new IntersectionObserver(([entry]) => {
  visible = entry.isIntersecting;
  schedule();
}).observe(display);
init();
