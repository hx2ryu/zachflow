#!/usr/bin/env node
// create-zachflow — bootstrap a new zachflow project via clone-and-strip.
//
// Usage:
//   npx create-zachflow my-project
//   npx create-zachflow my-project --repo=https://github.com/hx2ryu/zachflow.git
//   npx create-zachflow my-project --branch=main
//
// Env vars:
//   ZACHFLOW_REPO_URL — override default repo URL
//   ZACHFLOW_REF — override default ref (defaults to v${this package's version})

const { execSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const PKG_VERSION = require('./package.json').version;

const DEFAULT_REPO = process.env.ZACHFLOW_REPO_URL ||
  'https://github.com/hx2ryu/zachflow.git';
// Default ref tracks this package's own version: when create-zachflow@X.Y.Z runs,
// it clones the zachflow repo at vX.Y.Z. Pass --branch=main or --tag=<other> to override.
const DEFAULT_REF = process.env.ZACHFLOW_REF || `v${PKG_VERSION}`;

const STRIP_LIST = [
  '.git',
  'docs/superpowers',     // design history (contributors only)
  '.zachflow',            // per-project state (wizard creates fresh)
  'node_modules',         // npm install creates fresh
  'dist',                 // build output
  'package-lock.json',    // regenerate
];

// Argument parsing
const args = process.argv.slice(2);
let target = null;
let repoUrl = DEFAULT_REPO;
let ref = DEFAULT_REF;

for (const arg of args) {
  if (arg.startsWith('--repo=')) {
    repoUrl = arg.slice('--repo='.length);
  } else if (arg.startsWith('--branch=') || arg.startsWith('--tag=')) {
    ref = arg.slice(arg.indexOf('=') + 1);
  } else if (arg === '--help' || arg === '-h') {
    printHelp();
    process.exit(0);
  } else if (!arg.startsWith('--')) {
    if (target) {
      console.error('Error: multiple target directories specified');
      process.exit(1);
    }
    target = arg;
  } else {
    console.error(`Unknown flag: ${arg}`);
    process.exit(1);
  }
}

if (!target) {
  console.error('Usage: npx create-zachflow <project-name>');
  console.error('Run with --help for more options.');
  process.exit(1);
}

// Validate target doesn't exist or is empty
const targetPath = path.resolve(process.cwd(), target);
if (fs.existsSync(targetPath)) {
  const entries = fs.readdirSync(targetPath);
  if (entries.length > 0) {
    console.error(`Error: ${target} already exists and is not empty`);
    process.exit(1);
  }
}

console.log(`Cloning zachflow from ${repoUrl} (${ref})...`);

// 1. Shallow clone
try {
  execSync(`git clone --depth 1 --branch "${ref}" "${repoUrl}" "${targetPath}"`, { stdio: 'inherit' });
} catch (err) {
  console.error(`Error: git clone failed`);
  process.exit(1);
}

// 2. Strip dev artifacts
console.log('Stripping development artifacts...');
for (const item of STRIP_LIST) {
  const itemPath = path.join(targetPath, item);
  if (fs.existsSync(itemPath)) {
    fs.rmSync(itemPath, { recursive: true, force: true });
    console.log(`  removed: ${item}`);
  }
}

// 3. Re-init git
console.log('Initializing fresh git repo...');
execSync('git init -b main', { cwd: targetPath, stdio: 'inherit' });
execSync('git add .', { cwd: targetPath, stdio: 'inherit' });
execSync('git commit -m "chore: initial commit from zachflow template"', { cwd: targetPath, stdio: 'inherit' });

// 4. Print next steps
console.log('');
console.log(`✓ zachflow project created at ${target}/`);
console.log('');
console.log('Next steps:');
console.log(`  cd ${target}`);
console.log('  bash scripts/init-project.sh        # interactive wizard (~5 min)');
console.log('  # or for CI/scripted:');
console.log('  cp templates/init.config.template.yaml init.config.yaml');
console.log('  bash scripts/init-project.sh --from=init.config.yaml --non-interactive');
console.log('');

function printHelp() {
  console.log(`Usage:
  npx create-zachflow <project-name> [options]

Options:
  --repo=<url>       Override default zachflow repo URL
                     (default: ${DEFAULT_REPO})
  --branch=<name>    Clone a specific branch (e.g. main)
  --tag=<tag>        Clone a specific tag (default: v${PKG_VERSION} — this package's version)
  --help, -h         Show this message

Env vars:
  ZACHFLOW_REPO_URL  Override default repo URL
  ZACHFLOW_REF       Override default ref

Examples:
  npx create-zachflow my-project                      # clones v${PKG_VERSION}
  npx create-zachflow my-project --branch=main        # clones latest main
  npx create-zachflow my-project --tag=v1.0.0         # clones a specific tag
  ZACHFLOW_REPO_URL=https://github.com/me/zachflow.git npx create-zachflow my-project
`);
}
