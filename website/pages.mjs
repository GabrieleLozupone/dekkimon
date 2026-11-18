const repo = 'https://github.com/GabrieleLozupone/dekkimon';
const releases = `${repo}/releases/latest`;
const download = `${releases}/download`;
const kofi = 'https://ko-fi.com/gabrielelozupone';

const icons = {
  play: '<path d="m9 5 11 7-11 7V5Z"/>',
  pause: '<path d="M9 5v14m6-14v14"/>',
  arrow: '<path d="M4 12h15m-6-6 6 6-6 6"/>',
  external: '<path d="M6 18 18 6M8 6h10v10"/>',
  download: '<path d="M12 3v12m-5-5 5 5 5-5M4 19v2h16v-2"/>',
  terminal: '<path d="m5 6 5 6-5 6m8 0h6"/>',
  coffee: '<path d="M4 9h13v6a4 4 0 0 1-4 4H8a4 4 0 0 1-4-4V9Zm13 1h2a2.5 2.5 0 0 1 0 5h-2M8 3v3m5-3v3"/>',
  github: '<path fill="currentColor" stroke="none" d="M12 .75a11.25 11.25 0 0 0-3.56 21.92c.56.1.77-.24.77-.54l-.02-2.1c-3.13.68-3.8-1.33-3.8-1.33-.5-1.3-1.25-1.64-1.25-1.64-1.02-.7.08-.69.08-.69 1.13.08 1.72 1.16 1.72 1.16 1 1.72 2.64 1.22 3.28.93.1-.73.39-1.22.71-1.5-2.5-.28-5.12-1.25-5.12-5.56 0-1.23.44-2.24 1.16-3.03-.12-.28-.5-1.43.1-2.99 0 0 .95-.3 3.09 1.16a10.71 10.71 0 0 1 5.63 0c2.14-1.46 3.08-1.16 3.08-1.16.62 1.56.23 2.71.12 3A4.37 4.37 0 0 1 19.15 11c0 4.33-2.63 5.28-5.14 5.56.4.35.76 1.03.76 2.08l-.02 3.49c0 .3.2.65.78.54A11.25 11.25 0 0 0 12 .75Z"/>',
  bars: '<path fill="currentColor" stroke="none" d="M2 17h3v4H2zm5-4h3v8H7zm5-4h3v12h-3zm5-5h3v17h-3z"/>',
  menu: '<path d="M4 8h16M4 16h10"/>',
  chevron: '<path d="m9 18 6-6-6-6"/>',
  power: '<path d="M12 3v8m-5.2-4.6a7.5 7.5 0 1 0 10.4 0"/>',
  expand: '<path d="M14 4h6v6M10 20H4v-6m16-10-6.5 6.5M4 20l6.5-6.5"/>',
  close: '<path d="M6 6l12 12M18 6 6 18"/>',
};

export function icon(name) {
  return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${icons[name]}</svg>`;
}

export function logo(size = 34) {
  return `<svg class="logo-mark" viewBox="0 0 32 32" width="${size}" height="${size}" aria-hidden="true">
    <path class="logo-gate" d="M2.5 6.6c4.4 1.5 8.9 2.2 13.5 2.2s9.1-.7 13.5-2.2l-.9 3.4c-4.1 1.2-8.3 1.7-12.6 1.7s-8.5-.5-12.6-1.7l-.9-3.4ZM4.6 13.4h22.8v2.4H4.6zM6.6 10.9h2.8v18.6H6.6zM22.6 10.9h2.8v18.6h-2.8z"/>
    <circle class="logo-ring" cx="16" cy="22.6" r="4.5"/>
  </svg>`;
}

function image(src, alt, width, height, extra = '') {
  return `<img src="${src}" alt="${alt}" width="${width}" height="${height}" ${extra}>`;
}

function button(href, label, glyph = 'arrow', style = 'button-secondary') {
  return `<a class="button ${style}" href="${href}">${label}${icon(glyph)}</a>`;
}

function title(kicker, heading, summary) {
  return `<div class="page-intro">
    <p class="eyebrow">${kicker}</p>
    <h1>${heading}</h1>
    <p class="lede">${summary}</p>
  </div>`;
}

export function demo(root, alt = 'The Dekkimon app opening a Remote Play session') {
  return `<div class="connect-recording" data-recording data-src="${root}media/connect.gif">
    ${image(`${root}assets/connect-poster.webp`, alt, 560, 350, 'loading="lazy" decoding="async"')}
    <button type="button" class="recording-button" aria-pressed="false" hidden>
      ${icon('play')}${icon('pause')}<span>Play connection demo</span>
    </button>
    <noscript><a class="recording-link" href="${root}media/connect.gif">Open the connection GIF</a></noscript>
  </div>`;
}

function portalChrome() {
  const appIcon = name => image(`assets/portal/${name}.svg`, '', 48, 48);
  return `
    <div class="screen-header screen-idle">
      <div class="screen-tabs"><span>${appIcon('controller')}</span><span>${appIcon('console')}</span><span>${appIcon('settings')}</span></div>
      <div class="screen-corner"><span class="screen-signal">${icon('bars')} Excellent</span><time>8:19 PM</time></div>
    </div>
    <div class="screen-copy screen-idle"><span>Connect to “Living room PS5”</span><span>Available on your network</span></div>
    <span class="screen-globe-target screen-idle" data-connect-target></span>
    <div class="screen-hints screen-idle">
      <span class="screen-hint screen-connect-hint" data-connect-target><span class="screen-glyph">A</span> Connect</span>
      <span class="screen-hint"><span class="screen-hint-glyphs">${appIcon('l1')}${appIcon('r1')}</span> Switch tabs</span>
      <span class="screen-hint">${appIcon('options-badge')} Quick menu</span>
    </div>
    <div class="screen-copy screen-starting"><span>Connecting to “Living room PS5”</span><span>Starting Remote Play</span></div>`;
}

const tourScreens = [
  { id: 'consoles', tab: 'Consoles', alt: 'The Dekkimon console library', title: 'Pair once. Play at home or away.', text: 'Keep your PS5 and PS4 in one library. Sign in with a QR code on your phone, then wake your console and connect from Gaming Mode.', link: ['guides/first-connection/', 'Connect your console'] },
  { id: 'pair-console', tab: 'Pairing', alt: 'The Pair your PlayStation screen', title: 'Pairing that fits the controller.', text: 'Enter the console address and the 8-digit code shown on your PlayStation, all with the Deck’s buttons and on-screen keyboard.', link: ['guides/first-connection/', 'Pair your PlayStation'] },
  { id: 'stream-menu', tab: 'Quick menu', alt: 'The in-stream quick menu', title: 'Adjust your stream while you play.', text: 'Press R4 to check Wi-Fi or adjust your picture, volume and microphone. L4 opens the PS menu, and a left trackpad click acts as the touchpad.', link: ['guides/controls/', 'See the controls'] },
  { id: 'connection-page', tab: 'Connection', alt: 'The connection details page', title: 'Know what your Wi-Fi can do.', text: 'See signal, link speed and live bitrate side by side, with the speed each quality level needs.', link: ['guides/network-optimization/', 'Optimize your network'] },
  { id: 'stream-picture-hdr', tab: 'Picture & HDR', alt: 'The Picture and HDR menu', title: 'Make the picture yours.', text: 'Switch screen fit, rendering quality and HDR without leaving your game.', link: ['guides/settings/', 'Explore the settings'] },
  { id: 'settings-streaming', tab: 'Settings', alt: 'The streaming settings page', title: 'Separate settings for home and away.', text: 'Choose resolution, frame rate, bitrate and codec for each console type, with different defaults when you play over the internet.', link: ['guides/settings/', 'Explore the settings'] },
];

const highlights = [
  ['1080p · 60 fps', 'H.265 with HDR'],
  ['Home or away', 'Local network or PSN'],
  ['Gaming Mode', 'Controller-first interface'],
  ['Free', 'Open source, AGPL-3.0'],
];

export function home() {
  return `
  <section class="hero" aria-labelledby="hero-title" data-portal>
    <div class="hero-light" aria-hidden="true"></div>
    <div class="wrap hero-head">
      <h1 id="hero-title">Your PlayStation. <span class="h1-dim">Now on Deck.</span></h1>
      <p>Stream your PS5 or PS4 to Steam Deck, at home or away.</p>
      <div class="actions">
        ${button('install/', 'Install on Steam Deck', 'download', 'button-primary')}
        ${button('#tour', 'How it works', 'arrow')}
      </div>
    </div>
    <div class="deck-scene">
      <div class="deck-stage" id="portal-preview" role="group" aria-label="Interactive Steam Deck display">
        ${image('assets/deck-frame.webp', 'Front view of a Steam Deck', 1600, 760, 'class="deck-frame" fetchpriority="high"')}
        <div class="portal-frame" aria-hidden="true">
          <div class="portal-stage">
            ${image('assets/portal-still.webp', '', 960, 629, 'class="portal-still"')}
            ${image('assets/portal-stream.webp', '', 960, 629, 'class="portal-stream" fetchpriority="low"')}
            <canvas class="portal-canvas" hidden></canvas>
            ${portalChrome()}
            <div class="stream-toast">Connected · 1080p · 60 fps</div>
            <span class="stream-hint"><span class="screen-key">R4</span> Quick menu</span>
            ${image('assets/quick-menu.webp', '', 430, 800, 'class="quick-menu" loading="lazy" decoding="async"')}
          </div>
        </div>
      </div>
      <div class="demo-dock">
        <p class="dock-status"><span role="status">Try it: connect to the demo PS5</span></p>
        <ol class="demo-steps" aria-label="Demo progress">
          <li data-step="connect"><span class="sr-only">Connect</span></li>
          <li data-step="play"><span class="sr-only">Play</span></li>
          <li data-step="menu"><span class="sr-only">Quick menu</span></li>
        </ol>
        <div class="dock-actions">
          <button class="button button-primary connect-button" type="button" aria-controls="portal-preview" hidden>${icon('play')}<span>Connect</span></button>
          <button class="button button-primary menu-button" type="button" aria-controls="portal-preview" hidden><span class="key-badge">R4</span><span>Open quick menu</span></button>
          <button class="dock-icon disconnect-button" type="button" aria-controls="portal-preview" aria-label="Disconnect" title="Disconnect" hidden>${icon('power')}</button>
          <button class="dock-icon motion-button" type="button" aria-label="Pause portal animation" hidden>${icon('pause')}${icon('play')}</button>
        </div>
      </div>
    </div>
  </section>
  <section class="wrap highlights" aria-label="Highlights">
    <ul>${highlights.map(([title, detail]) => `<li><strong>${title}</strong><span>${detail}</span></li>`).join('')}</ul>
  </section>
  <section class="tour" id="tour" aria-labelledby="features-title" data-tour>
    <div class="wrap section-heading reveal">
      <p class="eyebrow">Inside Dekkimon</p>
      <h2 id="features-title">Made for the Steam Deck.</h2>
      <p class="lede">Every screen is built for the controller, from pairing to the in-game menu.</p>
      <div class="tour-tabs" role="tablist" aria-label="Dekkimon screens">
        ${tourScreens.map(({ id, tab }, index) => `<button type="button" role="tab" aria-controls="tour-copy" aria-selected="${index === 0}" data-screen="${id}"><span>${tab}</span><i></i></button>`).join('')}
      </div>
    </div>
    <div class="tour-scene reveal">
      <div class="tour-deck">
        ${image('assets/deck-frame.webp', '', 1600, 760, 'class="deck-frame" loading="lazy" decoding="async"')}
        <button type="button" class="tour-screen" aria-label="Enlarge the current screen">
          ${tourScreens.map(({ id, alt }, index) => image(`assets/tour/${id}.webp`, alt, 1280, 800, `data-screen="${id}" loading="lazy" decoding="async"${index ? '' : ' class="is-active"'}`)).join('')}
          <span class="zoom-chip">${icon('expand')} Enlarge</span>
        </button>
      </div>
    </div>
    <div class="wrap tour-panel reveal">
      <div class="tour-copy" id="tour-copy" role="tabpanel">
        ${tourScreens.map(({ id, title, text, link }, index) => `<article data-screen="${id}"${index ? ' hidden' : ''}>
          <h3>${title}</h3>
          <p>${text}</p>
          <a class="story-link" href="${link[0]}">${link[1]} ${icon('arrow')}</a>
        </article>`).join('')}
      </div>
    </div>
    <dialog class="lightbox" aria-label="Enlarged screenshot">
      <form method="dialog"><button class="lightbox-close" aria-label="Close">${icon('close')}</button></form>
      <img alt="" width="1280" height="800">
    </dialog>
  </section>
  <section class="final-cta">
    <div class="wrap">
      <h2>Ready to play?</h2>
      <p class="lede">Install in Desktop Mode, then launch Dekkimon from your Steam library.</p>
      <div class="actions">${button('install/', 'Install Dekkimon', 'download', 'button-primary')}${button('guides/first-connection/', 'First connection')}</div>
    </div>
  </section>`;
}

export const guides = [
  { slug: 'first-connection', name: 'First connection', group: 'Getting started', summary: 'Enable Remote Play, sign in on your phone, and pair your PlayStation.' },
  { slug: 'controls', name: 'Controls', group: 'Getting started', summary: 'Find the PS button, stream menu, touchpad, and controller shortcuts.' },
  { slug: 'network-optimization', name: 'Network optimization', group: 'Streaming', summary: 'Tune Wi-Fi, bitrate, refresh rate, and HDR for smoother streaming.' },
  { slug: 'settings', name: 'Settings', group: 'Streaming', summary: 'Understand your options for video, audio, controllers, and remote access.' },
];

export function guideIndex() {
  return `<div class="wrap inner-page guides-page">
    <header class="editorial-heading">
      <h1>Guides</h1>
      <p class="lede">Set up Remote Play and get more out of your Steam Deck.</p>
    </header>
    <div class="guide-index">
      ${['Getting started', 'Streaming'].map(group => `<section class="guide-group">
        <h2>${group}</h2>
        <ul>${guides.filter(guide => guide.group === group).map(({ slug, name, summary }) => `
          <li><a href="${slug}/"><span class="guide-title">${name}</span><span class="guide-summary">${summary}</span>${icon('arrow')}</a></li>`).join('')}</ul>
      </section>`).join('')}
      <section class="guide-help" aria-labelledby="troubleshooting">
        <h2 id="troubleshooting">Troubleshooting</h2>
        <div class="text-links">
          <a href="network-optimization/#troubleshooting">Stream quality</a>
          <a href="first-connection/#troubleshooting">Pairing and PSN</a>
          <a href="controls/#troubleshooting">Controller input</a>
          <a href="../install/#troubleshooting">Installation</a>
        </div>
      </section>
    </div>
  </div>`;
}

export function install(article, toc) {
  return `<div class="wrap inner-page">
    <div class="install-hero">
      <div>
        ${title('Steam Deck · SteamOS 3.9+', 'Install Dekkimon.', 'Download the installer in Desktop Mode. It adds Dekkimon to your Steam library with artwork and a ready-to-use controller layout.')}
        <div class="actions">
          ${button(`${download}/Install.Dekkimon.desktop`, 'Download installer', 'download', 'button-primary')}
          ${button('#manual-installation', 'Manual install', 'terminal')}
        </div>
        <a class="under-link" href="${releases}">View latest release ${icon('external')}</a>
      </div>
      <div class="install-deck">
        <div class="tour-deck">
          ${image('../assets/deck-frame.webp', 'Dekkimon running on a Steam Deck', 1600, 760, 'class="deck-frame" fetchpriority="high"')}
          <span class="tour-screen">${image('../assets/tour/home.webp', '', 1280, 800, 'class="is-active" fetchpriority="high"')}</span>
        </div>
      </div>
    </div>
    ${articleLayout(article, toc)}
  </div>`;
}

export function articleLayout(article, toc) {
  return `<div class="article-layout">
    <aside class="article-sidebar">
      <nav aria-label="On this page">
        <p class="eyebrow">On this page</p>
        <ul>${toc.map(({ id, label }) => `<li><a href="#${id}">${label}</a></li>`).join('')}</ul>
      </nav>
    </aside>
    <article class="prose">${article}</article>
  </div>`;
}

export function guideArticle(name, heading, article, toc) {
  return `<div class="wrap inner-page">
    <nav class="breadcrumbs" aria-label="Breadcrumb"><a href="../">Guides</a>${icon('chevron')}<span aria-current="page">${name}</span></nav>
    <header class="article-intro"><h1>${heading}</h1></header>
    ${articleLayout(article, toc)}
  </div>`;
}

export function faq() {
  const questions = [
    ['What is Dekkimon?', 'Dekkimon is an open-source Remote Play client for Steam Deck. It streams from your own PS5 or PS4. The console runs the game and your Deck sends the controls.'],
    ['Which Steam Deck models are supported?', 'Dekkimon supports both Steam Deck LCD and OLED on SteamOS 3.9 or newer. HDR output requires an HDR-capable screen and SteamOS HDR enabled.'],
    ['Can I play away from home?', 'Yes. Sign in to PlayStation Network in Dekkimon and follow the <a href="../guides/first-connection/#playing-away-from-home">away-from-home setup</a>. Stream quality depends on the connection at both ends.'],
    ['Do I need PlayStation Plus?', 'Remote Play itself doesn’t require PlayStation Plus. Any subscription requirements for the game or its online multiplayer still apply.'],
    ['How do I open the PS menu or stream menu?', 'With the included Steam Input layout, press L4 for the PS button and R4 for the Dekkimon stream menu. See the <a href="../guides/controls/">controls guide</a> for touchpad and controller shortcuts.'],
    ['What can I do if the picture stutters or freezes?', 'Start with the <a href="../guides/network-optimization/#quick-checklist">network checklist</a> and check the <a href="../guides/network-optimization/#troubleshooting">troubleshooting table</a> for your symptoms.'],
    ['Will updating remove my consoles or settings?', 'Run the same installer to update. It keeps your paired consoles, settings, and PlayStation Network sign-in. See the <a href="../install/#update">update instructions</a>.'],
    ['Is Dekkimon free?', 'Yes. Dekkimon is free and open source. You can read the <a href="../credits/">credits and license</a> or support its development on Ko-fi.'],
  ];
  return `<div class="wrap inner-page faq-page">
    ${title('FAQ', 'Frequently asked questions.', 'Answers about compatibility, Remote Play, and using Dekkimon on your Steam Deck.')}
    <div class="faq-list">
      ${questions.map(([question, answer]) => `<details><summary>${question}<span aria-hidden="true"></span></summary><p>${answer}</p></details>`).join('')}
    </div>
    <a class="under-link" href="${repo}/issues">Ask a question on GitHub ${icon('external')}</a>
  </div>`;
}

export function credits() {
  return `<div class="wrap inner-page credits-page">
    <header class="editorial-heading">
      <h1>Credits &amp; license</h1>
      <p class="lede">Dekkimon is maintained by Gabriele Lozupone and builds on the work of the Chiaki community.</p>
      <div class="project-links">
        <a href="${repo}">${icon('github')} Source on GitHub</a>
        <a href="${kofi}">${icon('coffee')} Support on Ko-fi</a>
      </div>
    </header>
    <dl class="credit-list">
      <div><dt>License</dt>
        <dd>Dekkimon is available under the <a href="${repo}/blob/main/COPYING">GNU Affero General Public License v3</a>, with the <a href="${repo}/blob/main/LICENSES/AGPL-3.0-only-OpenSSL.txt">OpenSSL exception</a>, and is distributed without warranty.</dd>
      </div>
      <div><dt>Remote Play</dt>
        <dd><a href="https://github.com/chiaki-ng/chiaki-ng">chiaki-ng</a> by Street Pea and contributors is Dekkimon’s foundation. It builds on <a href="https://git.sr.ht/~thestr4ng3r/chiaki">Chiaki</a> by Florian Markl, who reverse-engineered the PlayStation Remote Play protocol for the original client.</dd>
      </div>
      <div><dt>QR codes</dt>
        <dd>Phone sign-in uses <a href="https://www.nayuki.io/page/qr-code-generator-library">qrcodegen</a> by Project Nayuki, under the <a href="${repo}/blob/main/third-party/qrcodegen/qrcodegen.hpp">MIT license</a>.</dd>
      </div>
      <div><dt>Typography</dt>
        <dd><a href="../assets/fonts/OFL-Sora.txt">Sora</a> and <a href="../assets/fonts/OFL-ZenKakuGothicNew.txt">Zen Kaku Gothic New</a> are self-hosted under the SIL Open Font License 1.1.</dd>
      </div>
      <div><dt>Non-affiliation</dt>
        <dd>Dekkimon is an independent project and is not affiliated with, endorsed by, or certified by Sony Interactive Entertainment or Valve. PlayStation, PS5, PS4, and DualSense are trademarks of Sony Interactive Entertainment. Steam and Steam Deck are trademarks of Valve Corporation.</dd>
      </div>
    </dl>
  </div>`;
}

export function layout({ root, href, group, name, description, body }) {
  const nav = [['install/', 'Install'], ['guides/', 'Guides'], ['faq/', 'FAQ'], ['credits/', 'Credits']];
  const navLinks = items => items.map(([route, label]) =>
    `<a href="${root}${route}"${href === route ? ' aria-current="page"' : group === route ? ' aria-current="location"' : ''}>${label}</a>`).join('');
  const fullTitle = name ? `${name} · Dekkimon` : 'Dekkimon — PlayStation Remote Play for Steam Deck';
  const address = 'https://gabrielelozupone.github.io/dekkimon/';
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#101010">
  <meta name="description" content="${description}">
  <meta property="og:title" content="${fullTitle}">
  <meta property="og:description" content="${description}">
  <meta property="og:image" content="${address}media/social-preview.png">
  <meta property="og:url" content="${address}${href}">
  <title>${fullTitle}</title>
  <link rel="icon" href="${root}assets/icon.png" type="image/png">
  <link rel="stylesheet" href="${root}assets/style.css">
  <script type="module" src="${root}assets/site.js"></script>
  ${href === '' ? `<script type="module" src="${root}assets/portal.js"></script>` : ''}
</head>
<body>
  <a class="skip-link" href="#main">Skip to content</a>
  <header class="site-header">
    <div class="wrap header-inner">
      <a class="brand" href="${root || './'}"${href === '' ? ' aria-current="page"' : ''}>${logo()}<span>Dekkimon</span></a>
      <nav class="site-nav" aria-label="Main navigation">${navLinks(nav.slice(1))}</nav>
      <div class="header-actions">
        <a class="social-icon" href="${repo}" aria-label="GitHub" title="GitHub">${icon('github')}</a>
        <a class="social-icon" href="${kofi}" aria-label="Ko-fi" title="Ko-fi">${icon('coffee')}</a>
        <a class="button button-primary header-install" href="${root}install/"${href === 'install/' ? ' aria-current="page"' : ''}>Install</a>
      </div>
      <details class="mobile-menu">
        <summary>${icon('menu')} Menu</summary>
        <nav aria-label="Main navigation">${navLinks(nav)}<a href="${repo}">GitHub ${icon('github')}</a><a href="${kofi}">Ko-fi ${icon('coffee')}</a></nav>
      </details>
    </div>
  </header>
  <main id="main" tabindex="-1">${body}</main>
  <footer class="site-footer">
    <div class="wrap footer-inner">
      <a class="brand" href="${root || './'}">${logo()}<span>Dekkimon <span class="footer-jp" lang="ja">デッキ門</span></span></a>
      <nav aria-label="Project links"><a href="${root}credits/">Credits &amp; license</a><a class="social-icon" href="${repo}" aria-label="GitHub" title="GitHub">${icon('github')}</a><a class="social-icon" href="${kofi}" aria-label="Ko-fi" title="Ko-fi">${icon('coffee')}</a></nav>
    </div>
  </footer>
</body>
</html>`;
}
