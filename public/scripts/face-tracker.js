const P_MIN = -15;
const P_MAX = 15;
const STEP = 2.5;
const SIZE = 512;

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function quantizeToGrid(val) {
  const raw = P_MIN + (val + 1) * (P_MAX - P_MIN) / 2;
  const snapped = Math.round(raw / STEP) * STEP;
  return clamp(snapped, P_MIN, P_MAX);
}

function sanitize(val) {
  const str = Number(val).toFixed(1);
  return str.replace('-', 'm').replace('.', 'p');
}

function gridToFilename(px, py) {
  return `gaze_px${sanitize(px)}_py${sanitize(py)}_${SIZE}.webp`;
}

function updateDebug(debugEl, x, y, filename) {
  if (!debugEl) return;
  debugEl.innerHTML = `Mouse: (${Math.round(x)}, ${Math.round(y)})<br/>Image: ${filename}`;
}

function initializeFaceTracker(container) {
  const basePath = container.dataset.basePath || '/faces/';
  const showDebug = String(container.dataset.debug || 'false') === 'true';

  const img = document.createElement('img');
  img.className = 'face-image';
  img.alt = 'Face following gaze';
  container.appendChild(img);

  let debugEl = null;
  if (showDebug) {
    debugEl = document.createElement('div');
    debugEl.className = 'face-debug';
    container.appendChild(debugEl);
  }

  function setFromClient(clientX, clientY) {
    const rect = container.getBoundingClientRect();

    const nx = ((clientX / window.innerWidth) - 0.5) * 2;
    const ny = (0.5 - (clientY / window.innerHeight)) * 2;

    const clampedX = clamp(nx, -1, 1);
    const clampedY = clamp(ny, -1, 1);

    const px = quantizeToGrid(clampedX);
    const py = quantizeToGrid(clampedY);

    const filename = gridToFilename(px, py);
    const imagePath = `${basePath}${filename}`;
    img.src = imagePath;

    updateDebug(debugEl, clientX, clientY, filename);
  }


  function handleMouseMove(e) {
    setFromClient(e.clientX, e.clientY);
  }

  function handleTouchMove(e) {
    if (e.touches && e.touches.length > 0) {
      const t = e.touches[0];
      setFromClient(t.clientX, t.clientY);
    }
  }

  window.addEventListener('mousemove', handleMouseMove);
  window.addEventListener('touchmove', handleTouchMove, { passive: true });

  const rect = container.getBoundingClientRect();
  setFromClient(rect.left + rect.width / 2, rect.top + rect.height / 2);
}

document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('.face-tracker').forEach((el) => initializeFaceTracker(el));
});
