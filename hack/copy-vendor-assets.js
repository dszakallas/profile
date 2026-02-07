#!/usr/bin/env node

/**
 * Copy vendor assets from node_modules to a target directory
 * This runs automatically after npm install via the postinstall script
 *
 * Usage: node copy-vendor-assets.js <vendor-dir>
 */

import fs from 'fs-extra';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Get vendor directory from command line argument (required)
if (!process.argv[2]) {
  console.error('Error: Vendor directory argument is required');
  console.error('Usage: node copy-vendor-assets.js <vendor-dir>');
  process.exit(1);
}

const VENDOR_DIR = path.resolve(process.argv[2]);

// Define what to copy from each package
const assets = [
  {
    package: '@fortawesome/fontawesome-free',
    files: [
      { src: 'css/all.min.css', dest: 'fontawesome/css/all.min.css' },
      { src: 'webfonts', dest: 'fontawesome/webfonts' }
    ]
  },
  {
    package: 'jquery',
    files: [
      { src: 'dist/jquery.min.js', dest: 'jquery/jquery.min.js' }
    ]
  },
  {
    package: 'chart.js',
    files: [
      { src: 'dist/chart.umd.js', dest: 'chart/chart.min.js' }
    ]
  },
  {
    package: 'gitalk',
    files: [
      { src: 'dist/gitalk.min.js', dest: 'gitalk/gitalk.min.js' },
      { src: 'dist/gitalk.css', dest: 'gitalk/gitalk.css' }
    ]
  },
  {
    package: 'valine',
    files: [
      { src: 'dist/Valine.min.js', dest: 'valine/Valine.min.js' }
    ]
  },
  {
    package: 'mathjax',
    files: [
      { src: 'es5', dest: 'mathjax/es5' }
    ]
  },
  {
    package: 'mermaid',
    files: [
      { src: 'dist/mermaid.min.js', dest: 'mermaid/mermaid.min.js' },
      { src: 'dist/mermaid.esm.min.mjs', dest: 'mermaid/mermaid.esm.min.mjs' }
    ]
  }
];

async function copyAssets() {
  console.log('Copying vendor assets...');

  // Clean vendor directory
  await fs.remove(VENDOR_DIR);
  await fs.ensureDir(VENDOR_DIR);

  for (const asset of assets) {
    const packagePath = path.join(__dirname, '..', 'node_modules', asset.package);

    for (const file of asset.files) {
      const srcPath = path.join(packagePath, file.src);
      const destPath = path.join(VENDOR_DIR, file.dest);

      try {
        await fs.copy(srcPath, destPath);
        console.log(`✓ Copied ${asset.package}/${file.src} -> ${file.dest}`);
      } catch (error) {
        console.error(`✗ Failed to copy ${asset.package}/${file.src}:`, error.message);
      }
    }
  }

  console.log('Done copying vendor assets!');
}

copyAssets().catch(error => {
  console.error('Error copying assets:', error);
  process.exit(1);
});

