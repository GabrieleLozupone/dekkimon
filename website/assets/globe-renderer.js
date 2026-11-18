// WebGL port of gui/src/qml/shaders/portalglobe.frag.
// Keep the Fibonacci shells, particle clustering, corona and opening mask.
// Lay out the shells once on the CPU, then rotate and draw them as point sprites.

const vertexScreen = `
attribute vec2 position;
void main() { gl_Position = vec4(position, 0.0, 1.0); }
`;

const portalGeometry = `
uniform vec2 viewport;
uniform float radius, energy, reveal, pulse;

vec2 center() { return viewport * vec2(0.5, 0.47); }
float zoom() { return 1.0 + 1.8 * reveal * reveal; }
float holeRadius() { return reveal * (length(max(center(), viewport - center())) / radius + 0.07); }
float holeSoftness() { return 0.015 + 0.06 * reveal; }
float portalMask(float distance) {
  if (reveal <= 0.0) return 1.0;
  return smoothstep(holeRadius(), holeRadius() + holeSoftness(), distance);
}
float gaussian(float x) { return exp(-x * x); }
`;

const fragmentScreen = `
precision highp float;
${portalGeometry}
void main() {
  vec2 delta = gl_FragCoord.xy - center();
  vec2 uv = gl_FragCoord.xy / viewport;
  float distance = length(delta) / radius;
  float r = distance / zoom();
  float breathe = 0.5 + 0.5 * sin(pulse);
  float floor = 1.0 - uv.y;
  vec3 col = mix(vec3(0.016, 0.020, 0.035), vec3(0.060, 0.070, 0.100), smoothstep(0.15, 1.0, floor));
  col += vec3(0.0, 0.025, 0.065) * smoothstep(0.6, 1.0, floor) * (1.0 - abs(uv.x - 0.5));

  float outside = max(r - 1.0, 0.0);
  float spill = exp(-outside * 2.2) * (0.10 + 0.055 * breathe + 0.15 * energy);
  col += vec3(0.0, 0.13, 0.43) * spill;

  float corona = exp(-outside * 10.0) * (0.54 + 0.13 * breathe + 0.38 * energy)
               + exp(-outside * 4.1) * (0.18 + 0.09 * breathe + 0.25 * energy);
  float wave = fract(pulse / 6.2831853);
  float ripple = gaussian((r - 1.0 - wave * 0.57) / 0.026) * (1.0 - wave) * energy * 0.7;
  vec3 coronaColor = mix(vec3(0.025, 0.28, 0.83), vec3(0.13, 0.52, 1.0), breathe);
  col += coronaColor * (corona + ripple);

  float edge = 1.0 - smoothstep(1.0 - 0.7 / radius, 1.0 + 0.7 / radius, r);
  vec3 body = mix(vec3(0.009, 0.028, 0.096), vec3(0.018, 0.089, 0.28), pow(min(r, 1.0), 3.1));
  body += vec3(0.16, 0.48, 1.0) * gaussian((1.0 - r) / 0.024) * (0.69 + 0.2 * breathe + 0.38 * energy);
  col = mix(col, body, edge);

  float mask = portalMask(distance);
  float ring = gaussian((distance - holeRadius() - holeSoftness() * 0.4) / (0.025 + reveal * 0.035))
             * (1.0 - reveal) * smoothstep(0.0, 0.06, reveal);
  gl_FragColor = vec4(col * mask + vec3(0.36, 0.66, 1.0) * ring, min(1.0, mask + ring));
}
`;

const vertexParticles = `
${portalGeometry}
uniform float time, spin;
attribute vec3 point;
attribute vec3 seed;
varying vec3 tint;
varying float brightness, brightStar;

mat3 rotY(float a) { float c = cos(a), s = sin(a); return mat3(c, 0.0, -s, 0.0, 1.0, 0.0, s, 0.0, c); }
mat3 rotX(float a) { float c = cos(a), s = sin(a); return mat3(1.0, 0.0, 0.0, 0.0, c, s, 0.0, -s, c); }

void main() {
  vec3 p = rotX(0.32) * rotY(spin) * point;
  gl_Position = vec4((center() + p.xy * radius * zoom()) / viewport * 2.0 - 1.0, 0.0, 1.0);
  brightStar = seed.z;
  float spriteSize = mix(mix(2.6, 5.1, seed.y), mix(10.0, 17.0, seed.y), brightStar);
  gl_PointSize = max(2.0, spriteSize * radius / 155.0 * zoom());
  vec3 smallTint = mix(vec3(0.035, 0.24, 0.81), vec3(0.17, 0.56, 1.0), seed.x);
  vec3 starTint = mix(vec3(0.35, 0.63, 1.0), vec3(0.8, 0.93, 1.0), seed.y);
  tint = mix(smallTint, starTint, brightStar);
  float twinkle = 0.62 + 0.38 * sin(time * (1.2 + seed.x * 2.6) + seed.y * 6.2831);
  float limb = smoothstep(0.0, 0.44, abs(p.z) / length(point));
  float depth = mix(0.24, 1.0, p.z * 0.5 + 0.5);
  brightness = twinkle * depth * limb * (1.0 + 0.7 * energy);
}
`;

const fragmentParticles = `
precision highp float;
${portalGeometry}
varying vec3 tint;
varying float brightness, brightStar;
void main() {
  vec2 point = (gl_PointCoord - 0.5) * 2.0;
  float r = length(point);
  float core = gaussian(r / mix(0.28, 0.16, brightStar));
  float glow = gaussian(r / mix(0.4, 0.52, brightStar)) * mix(0.19, 0.38, brightStar);
  float mask = portalMask(length(gl_FragCoord.xy - center()) / radius);
  gl_FragColor = vec4(tint * (core + glow) * (1.0 - smoothstep(0.75, 1.0, r)) * brightness * mask, 0.0);
}
`;

const phi = (1 + Math.sqrt(5)) / 2;
const tau = Math.PI * 2;
const fract = value => value - Math.floor(value);
const mix = (a, b, t) => a + (b - a) * t;
const cubic = t => t * t * (3 - 2 * t);
const smooth = (a, b, t) => cubic(Math.max(0, Math.min(1, (t - a) / (b - a))));

function hash(value) {
  const p = fract(value * 0.1031);
  return fract(p * (p + 33.33) * p * (p + 33.33) * 2);
}

function hash3(x, y, z) {
  const a = fract(x * 0.1031);
  const b = fract(y * 0.1031);
  const c = fract(z * 0.1031);
  const offset = a * (c + 31.32) + b * (b + 31.32) + c * (a + 31.32);
  return fract((a + b + 2 * offset) * (c + offset));
}

function noise3(x, y, z) {
  const i = Math.floor(x), j = Math.floor(y), k = Math.floor(z);
  const u = cubic(fract(x)), v = cubic(fract(y)), w = cubic(fract(z));
  const slice = level => mix(mix(hash3(i, j, level), hash3(i + 1, j, level), u),
    mix(hash3(i, j + 1, level), hash3(i + 1, j + 1, level), u), v);
  return mix(slice(k), slice(k + 1), w);
}

function cloud(x, y, z, shell) {
  const p = [x, y, z].map(value => value * 2.1 + shell * 3.3);
  return 0.6 * noise3(...p) + 0.3 * noise3(...p.map(value => value * 2.03 + 7.1))
    + 0.1 * noise3(...p.map(value => value * 4.11 + 3.7));
}

function buildParticles() {
  const points = [];
  for (let shell = 0; shell < 5; shell += 1) {
    const radius = 1 - shell * 0.16;
    const tiltX = -shell * 0.71;
    const tiltY = -shell * 1.37;
    for (const bright of [0, 1]) {
      const count = Math.floor(bright ? 51 * radius ** 2 + 16 : 1900 * radius ** 2 + 300);
      for (let i = 0; i < count; i += 1) {
        const seed = i + shell * 7919 + bright * 50021;
        const h1 = hash(seed), h2 = hash(seed * 1.37 + 0.37), h3 = hash(seed * 0.71 + 0.71), h4 = hash(seed * 2.13 + 0.13);
        const azimuth = tau * fract(i * (phi - 1));
        const z = 1 - (2 * i + 1) / count;
        const r = Math.sqrt(1 - z * z);
        const jitter = (bright ? 1.2 : 2.6) / Math.sqrt(count);
        const raw = [r * Math.cos(azimuth), r * Math.sin(azimuth), z];
        const q = raw.map((value, index) => value + ([h2, h3, h4][index] - 0.5) * jitter);
        const length = Math.hypot(...q);
        const [x, y, depth] = q.map(value => value / length);
        const cluster = cloud(x, y, depth, shell);
        const density = bright ? 0.55 * smooth(0.35, 0.60, cluster) + 0.10 : 0.9 * smooth(0.38, 0.70, cluster) + 0.11;
        if (h1 > density) continue;
        const px = x * Math.cos(tiltY) + depth * Math.sin(tiltY);
        const pz = -x * Math.sin(tiltY) + depth * Math.cos(tiltY);
        points.push(px * radius, (y * Math.cos(tiltX) - pz * Math.sin(tiltX)) * radius,
          (y * Math.sin(tiltX) + pz * Math.cos(tiltX)) * radius, h2, h3, bright);
      }
    }
  }
  return new Float32Array(points);
}

function compile(gl, type, source) {
  const shader = gl.createShader(type);
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(shader));
  return shader;
}

function program(gl, vertex, fragment) {
  const vertexShader = compile(gl, gl.VERTEX_SHADER, vertex);
  const fragmentShader = compile(gl, gl.FRAGMENT_SHADER, fragment);
  const linked = gl.createProgram();
  gl.attachShader(linked, vertexShader);
  gl.attachShader(linked, fragmentShader);
  gl.linkProgram(linked);
  gl.deleteShader(vertexShader);
  gl.deleteShader(fragmentShader);
  if (!gl.getProgramParameter(linked, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(linked));
  const uniforms = Object.fromEntries(['viewport', 'radius', 'spin', 'time', 'energy', 'reveal', 'pulse']
    .map(name => [name, gl.getUniformLocation(linked, name)]));
  return { linked, uniforms };
}

function buffer(gl, vertices) {
  const handle = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, handle);
  gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW);
  return handle;
}

export function makeRenderer(canvas) {
  const gl = canvas.getContext('webgl', { alpha: true, antialias: false, powerPreference: 'low-power' });
  if (!gl || !gl.getShaderPrecisionFormat(gl.FRAGMENT_SHADER, gl.HIGH_FLOAT).precision) return null;

  const screen = program(gl, vertexScreen, fragmentScreen);
  const particles = program(gl, vertexParticles, fragmentParticles);
  const screenBuffer = buffer(gl, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]));
  const positions = buildParticles();
  const particleBuffer = buffer(gl, positions);
  const quad = gl.getAttribLocation(screen.linked, 'position');
  const point = gl.getAttribLocation(particles.linked, 'point');
  const seed = gl.getAttribLocation(particles.linked, 'seed');
  gl.blendFuncSeparate(gl.ONE, gl.ONE, gl.ZERO, gl.ONE);

  function use(pass, state) {
    const { uniforms } = pass;
    gl.useProgram(pass.linked);
    gl.uniform2f(uniforms.viewport, canvas.width, canvas.height);
    gl.uniform1f(uniforms.radius, Math.min(canvas.width, canvas.height) * 0.36);
    for (const [name, value] of Object.entries(state)) gl.uniform1f(uniforms[name], value);
  }

  return function draw(state) {
    gl.viewport(0, 0, canvas.width, canvas.height);
    gl.disable(gl.BLEND);
    use(screen, state);
    gl.bindBuffer(gl.ARRAY_BUFFER, screenBuffer);
    gl.enableVertexAttribArray(quad);
    gl.vertexAttribPointer(quad, 2, gl.FLOAT, false, 0, 0);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
    gl.disableVertexAttribArray(quad);

    gl.enable(gl.BLEND);
    use(particles, state);
    gl.bindBuffer(gl.ARRAY_BUFFER, particleBuffer);
    gl.enableVertexAttribArray(point);
    gl.enableVertexAttribArray(seed);
    gl.vertexAttribPointer(point, 3, gl.FLOAT, false, 24, 0);
    gl.vertexAttribPointer(seed, 3, gl.FLOAT, false, 24, 12);
    gl.drawArrays(gl.POINTS, 0, positions.length / 6);
    gl.disableVertexAttribArray(point);
    gl.disableVertexAttribArray(seed);
  };
}
