import fs from 'node:fs';
import path from 'node:path';

export interface ProductDoc {
  product: string;
  type: string;
  title: string;
  resource: string;
  status: string;
  tags: string[];
  sourceSprint: string;
  updatedAt: string;
  relatedResources: string[];
  filePath: string;
  route: string;
  body: string;
  summary: string;
}

type Frontmatter = Record<string, string | string[] | null>;

const productTypeLabels: Record<string, string> = {
  product_index: 'Product',
  feature: 'Feature',
  api: 'API',
  decision: 'Decision',
  policy: 'Policy',
  glossary: 'Glossary',
  prd: 'PRD',
};

export function labelForType(type: string): string {
  return productTypeLabels[type] ?? type;
}

function parseValue(raw: string): string | string[] | null {
  const value = raw.trim();
  if (value === 'null') return null;
  if (value.startsWith('[') && value.endsWith(']')) {
    const inner = value.slice(1, -1).trim();
    if (!inner) return [];
    return inner.split(',').map((item) => stripQuotes(item.trim())).filter(Boolean);
  }
  return stripQuotes(value);
}

function stripQuotes(value: string): string {
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    return value.slice(1, -1);
  }
  return value;
}

function asList(value: string | string[] | null | undefined): string[] {
  if (Array.isArray(value)) return value;
  if (typeof value === 'string' && value.trim()) return [value.trim()];
  return [];
}

function parseFrontmatter(content: string): { frontmatter: Frontmatter; body: string } | null {
  if (!content.startsWith('---')) return null;
  const end = content.indexOf('---', 3);
  if (end < 0) return null;

  const frontmatter: Frontmatter = {};
  const lines = content.slice(3, end).split(/\r?\n/);
  let currentListKey: string | null = null;

  for (const line of lines) {
    if (!line.trim()) continue;
    const listMatch = line.match(/^\s*-\s+(.*)$/);
    if (listMatch && currentListKey) {
      const current = frontmatter[currentListKey];
      const list = Array.isArray(current) ? current : [];
      list.push(stripQuotes(listMatch[1].trim()));
      frontmatter[currentListKey] = list;
      continue;
    }

    const match = line.match(/^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$/);
    if (!match) continue;
    const [, key, rawValue] = match;
    if (rawValue.trim() === '') {
      frontmatter[key] = [];
      currentListKey = key;
    } else {
      frontmatter[key] = parseValue(rawValue);
      currentListKey = null;
    }
  }

  return {
    frontmatter,
    body: content.slice(end + 3).trim(),
  };
}

function summarize(body: string): string {
  return body
    .split(/\n{2,}/)
    .map((block) => block.trim())
    .filter((block) => block && !block.startsWith('#'))
    .shift() ?? '';
}

function routeFor(resource: string): { product: string; route: string } | null {
  const parts = resource.split('/');
  if (parts[0] !== 'products' || !parts[1]) return null;
  const product = parts[1];
  if (parts.length === 2) {
    return { product, route: `/kb/${product}/` };
  }
  return { product, route: `/kb/${product}/${parts.slice(2).join('/')}/` };
}

export function loadProductDocs(projectRoot = path.resolve('../..')): ProductDoc[] {
  const productsRoot = path.join(projectRoot, '.zachflow', 'kb', 'products');
  if (!fs.existsSync(productsRoot)) return [];

  const docs: ProductDoc[] = [];

  const walk = (dir: string) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(full);
        continue;
      }
      if (!entry.name.endsWith('.md')) continue;
      if (full === path.join(productsRoot, 'README.md')) continue;

      const parsed = parseFrontmatter(fs.readFileSync(full, 'utf-8'));
      if (!parsed) continue;
      const resource = String(parsed.frontmatter.resource ?? '');
      const routed = routeFor(resource);
      if (!routed) continue;

      docs.push({
        product: routed.product,
        type: String(parsed.frontmatter.type ?? ''),
        title: String(parsed.frontmatter.title ?? resource),
        resource,
        status: String(parsed.frontmatter.status ?? ''),
        tags: asList(parsed.frontmatter.tags),
        sourceSprint: String(parsed.frontmatter.source_sprint ?? ''),
        updatedAt: String(parsed.frontmatter.updated_at ?? ''),
        relatedResources: asList(parsed.frontmatter.related_resources),
        filePath: full,
        route: routed.route,
        body: parsed.body,
        summary: summarize(parsed.body),
      });
    }
  };

  walk(productsRoot);

  return docs.sort((a, b) => {
    if (a.product !== b.product) return a.product.localeCompare(b.product);
    if (a.type !== b.type) return a.type.localeCompare(b.type);
    return a.title.localeCompare(b.title);
  });
}
