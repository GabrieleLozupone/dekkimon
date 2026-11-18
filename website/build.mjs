import { copyFile, cp, mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Marked } from 'marked';
import { credits, demo, faq, guideArticle, guideIndex, guides, home, install, layout } from './pages.mjs';

const here = fileURLToPath(new URL('.', import.meta.url));
const repo = path.resolve(here, '..');
const out = path.join(repo, 'dist', 'website');
const media = new Map(
  ['connect.gif', 'social-preview.png']
    .map(name => [name, `docs/img/${name}`]),
);
const routes = new Map([
  ['install.md', 'install/'],
  ...guides.map(({ slug }) => [`${slug}.md`, `guides/${slug}/`]),
]);

function slug(text) {
  return text.toLowerCase().replace(/[^\p{L}\p{M}\p{N}_ -]/gu, '').replaceAll(' ', '-');
}

function copyImage(src, root) {
  const repoPath = path.posix.normalize(`docs/${src}`);
  if (!repoPath.startsWith('docs/img/') && !repoPath.startsWith('installer/steam/')) {
    throw new Error(`Unsupported image path: ${src}`);
  }
  const filename = repoPath.startsWith('installer/') ? `steam-${path.posix.basename(src)}` : path.posix.basename(src);
  media.set(filename, repoPath);
  return `${root}media/${filename}`;
}

async function renderDoc(filename, root, startAtSection = false) {
  const markdown = await readFile(path.join(repo, 'docs', filename), 'utf8');
  const toc = [];
  const ids = new Set();
  const marked = new Marked({
    renderer: {
      heading({ depth, text, tokens }) {
        const label = this.parser.parseInline(tokens, this.parser.textRenderer);
        const base = slug(text.replace(/[*`]/g, ''));
        let id = base;
        for (let suffix = 1; ids.has(id); suffix += 1) id = `${base}-${suffix}`;
        ids.add(id);
        if (depth === 2) toc.push({ id, label });
        return `<h${depth} id="${id}">${this.parser.parseInline(tokens)}</h${depth}>\n`;
      },
    },
    walkTokens(token) {
      if (token.type === 'link') {
        const [file, hash] = token.href.split('#');
        if (routes.has(file)) token.href = `${root}${routes.get(file)}${hash ? `#${hash}` : ''}`;
        if (file.startsWith('../')) {
          token.href = `https://github.com/GabrieleLozupone/dekkimon/blob/main/${path.posix.normalize(`docs/${token.href}`)}`;
        }
      }
      if (token.type === 'image') token.href = copyImage(token.href, root);
      if (token.type === 'html' && token.raw.startsWith('<p align="center"><img')) {
        if (token.raw.includes('src="img/connect.gif"')) {
          token.text = demo(root);
          return;
        }
        token.text = token.raw
          .replace('<p align="center">', '<div class="prose-media">')
          .replace('</p>', '</div>')
          .replace(/<img src="([^"]+)" alt="([^"]+)" width="[^"]+">/g, (_, src, alt) => {
            const classes = src.startsWith('../installer/') ? ' class="steam-art"' : '';
            return `<img src="${copyImage(src, root)}" alt="${alt}" loading="lazy" decoding="async"${classes}>`;
          });
      }
    },
  });
  const tokens = marked.lexer(markdown);
  const title = tokens.shift().text;
  const firstSection = startAtSection ? tokens.findIndex(token => token.type === 'heading' && token.depth === 2) : 0;
  const content = tokens.slice(firstSection);
  content.links = tokens.links;
  marked.walkTokens(content, marked.defaults.walkTokens);
  const html = marked.parser(content).replace(/<table>[\s\S]*?<\/table>/g, table =>
    `<div class="table-scroll" tabindex="0" role="region" aria-label="Guide table">${table}</div>`);
  return { title, html, toc };
}

async function page(href, name, description, body, group = href) {
  const root = '../'.repeat(href.split('/').length - 1);
  const directory = path.join(out, href);
  await mkdir(directory, { recursive: true });
  await writeFile(path.join(directory, 'index.html'), layout({ root, href, group, name, description, body }));
}

await mkdir(path.join(out, 'media'), { recursive: true });
await cp(path.join(here, 'assets'), path.join(out, 'assets'), { recursive: true });
const portalIcons = ['portal/controller.svg', 'portal/console.svg', 'portal/settings.svg', 'portal/options-badge.svg', 'l1.svg', 'r1.svg'];
const portalAssets = path.join(out, 'assets', 'portal');
await mkdir(portalAssets, { recursive: true });
await Promise.all(portalIcons.map(icon => copyFile(path.join(repo, 'gui', 'res', icon), path.join(portalAssets, path.basename(icon)))));

await page('', '', 'Dekkimon is an open-source PlayStation Remote Play client for Steam Deck. Stream PS5 and PS4 games, at home or away.', home());
const installDoc = await renderDoc('install.md', '../', true);
await page('install/', 'Install', 'Install, update or uninstall Dekkimon on Steam Deck, using the desktop installer or a local release archive.', install(installDoc.html, installDoc.toc));
await page('guides/', 'Guides', 'Dekkimon guides for pairing, controls, network optimization, settings and troubleshooting.', guideIndex());
await page('faq/', 'FAQ', 'Answers about Dekkimon, Steam Deck compatibility and PlayStation Remote Play.', faq());
await page('credits/', 'Credits &amp; license', 'The open-source projects, licenses and font credits behind Dekkimon.', credits());

for (const { slug: name, summary, name: label } of guides) {
  const doc = await renderDoc(`${name}.md`, '../../');
  await page(`guides/${name}/`, doc.title, summary, guideArticle(label, doc.title, doc.html, doc.toc), 'guides/');
}

await Promise.all([...media].map(([name, source]) => copyFile(path.join(repo, source), path.join(out, 'media', name))));
console.log(`Built Dekkimon website in ${path.relative(repo, out)}`);
