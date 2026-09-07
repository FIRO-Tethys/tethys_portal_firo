// apptainer/dev/scripts/make_cw3e_scoped_css.mjs
// Regenerates the vendored CW3E theme CSS scoped under .cw3e-scope.
// Usage: npm install && node make_cw3e_scoped_css.mjs [--out PATH]
import fs from "fs/promises";
import path from "path";
import postcss from "postcss";
import safeParser from "postcss-safe-parser";

const SCOPE = ".cw3e-scope";

const URLS = [
  "https://cw3e.ucsd.edu/wp-content/themes/twentysixteen-child/style.css?ver=1.0.0",
  "https://cw3e.ucsd.edu/wp-content/themes/twentysixteen/style.css",
  "https://cw3e.ucsd.edu/wp-content/themes/twentysixteen/fonts/merriweather-plus-montserrat-plus-inconsolata.css?ver=20230328",
  "https://cw3e.ucsd.edu/wp-content/themes/twentysixteen/genericons/genericons.css?ver=20201208",
  "https://cw3e.ucsd.edu/wp-content/themes/twentysixteen/css/blocks.css?ver=20230206",
  "https://cw3e.ucsd.edu?display_custom_css=css&ver=6.8.1",
];

function absolutizeCssUrls(cssText, cssUrl) {
  // Make url(../something) absolute so fonts/images still load after bundling
  return cssText.replace(/url\(\s*(['"]?)([^'")]+)\1\s*\)/g, (m, quote, raw) => {
    const u = raw.trim();
    if (
      u.startsWith("data:") ||
      u.startsWith("http://") ||
      u.startsWith("https://") ||
      u.startsWith("//") ||
      u.startsWith("/")
    ) {
      return m;
    }
    const abs = new URL(u, cssUrl).toString();
    return `url("${abs}")`;
  });
}

async function fetchCss(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Failed ${res.status} for ${url}`);
  let text = await res.text();
  if (url.includes("twentysixteen-child/style.css")) {
    text = text.replace(
      /@import\s+url\(["']https:\/\/cw3e\.ucsd\.edu\/wp-content\/themes\/twentysixteen\/style\.css["']\);\s*/g,
      ""
    );
  }  
  return absolutizeCssUrls(text, url);
}

function scopeSelector(sel) {
  const s = sel.trim();
  if (!s) return s;

  // If it's exactly html/body/:root, replace entirely
  if (s === "html" || s === "body" || s === ":root") return SCOPE;

  // If it starts with html/body/:root, replace that leading token with SCOPE
  // (handles: body.foo, html .x, :root[data-theme="dark"], etc.)
  let out = s.replace(/^(html|body|:root)\b/, SCOPE);

  // Collapse ".cw3e-scope body ..." or ".cw3e-scope html ..." → ".cw3e-scope ..."
  out = out.replace(new RegExp(`^${SCOPE}\\s+(html|body)\\b\\s*`), `${SCOPE} `);

  // If we didn't rewrite a leading html/body/:root, prefix the whole selector
  if (!out.startsWith(SCOPE)) {
    out = `${SCOPE} ${s}`;
  }

  return out;
}

const cw3eScopePlugin = () => ({
  postcssPlugin: "cw3e-scope-plugin",
  Rule(rule) {
    // Skip keyframe steps: from/to/0% selectors must NOT be prefixed
    const p = rule.parent;
    if (p && p.type === "atrule" && /keyframes$/i.test(p.name)) return;

    if (!rule.selector) return;

    const selectors = postcss.list.comma(rule.selector).map(scopeSelector);
    rule.selector = selectors.join(", ");
  },
});
cw3eScopePlugin.postcss = true;

async function main() {
  const chunks = await Promise.all(URLS.map(fetchCss));
  const inputCss = chunks.join("\n\n/* ---- next file ---- */\n\n");

  const result = await postcss([cw3eScopePlugin]).process(inputCss, {
    from: "cw3e_raw.css",
    to: "cw3e_scoped.css",
    parser: safeParser,
    map: false,
  });

  const repoRoot = path.resolve(import.meta.dirname, "../../..");
  const defaultOut = path.join(
    repoRoot,
    "custom_themes/tethysext-default_theme/tethysext/default_theme/public/css/cw3e_scoped.css",
  );
  const argOut = process.argv.indexOf("--out");
  const outPath = argOut === -1 ? defaultOut : path.resolve(process.argv[argOut + 1]);

  const MIN_BYTES = 50_000;
  if (Buffer.byteLength(result.css, "utf8") < MIN_BYTES) {
    throw new Error(
      `refusing to write ${Buffer.byteLength(result.css, "utf8")} bytes to ${outPath}; ` +
        `expected at least ${MIN_BYTES}. A source URL probably failed to fetch.`,
    );
  }

  await fs.mkdir(path.dirname(outPath), { recursive: true });
  await fs.writeFile(outPath, result.css, "utf8");

  console.log(`Wrote ${outPath}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});