import sharp from "sharp";
import { fileURLToPath } from "node:url";
import { readFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { Buffer } from "node:buffer";

const pathFromHere = (path) => fileURLToPath(new URL(path, import.meta.url));
const iconSource = pathFromHere("../public/fanbar-icon.png");
const snapshot = JSON.parse(await readFile(pathFromHere("../src/data/screenshots.json"), "utf8"));
const gitBlobHash = (buffer) => createHash("sha1").update(`blob ${buffer.length}\0`).update(buffer).digest("hex");

async function screenshotSource(asset) {
  // Reuse a local original only if it matches the pinned main screenshot.
  let buffer = await readFile(pathFromHere(`../../${asset.sourcePath}`)).catch(() => undefined);
  if (!buffer || gitBlobHash(buffer) !== asset.sourceSha) {
    const response = await fetch(`https://raw.githubusercontent.com/${snapshot.repository}/${snapshot.ref}/${asset.sourcePath}`, {
      signal: AbortSignal.timeout(30_000),
    });
    if (!response.ok) throw new Error(`Screenshot download failed (${response.status}): ${asset.sourcePath}`);
    buffer = Buffer.from(await response.arrayBuffer());
  }
  if (gitBlobHash(buffer) !== asset.sourceSha) throw new Error(`Screenshot source mismatch: ${asset.sourcePath}`);
  const { width, height } = await sharp(buffer).metadata();
  if (width !== asset.width || height !== asset.height) throw new Error(`Screenshot dimensions changed: ${asset.sourcePath}`);
  return buffer;
}

await Promise.all([
  sharp(iconSource)
    .resize(64, 64)
    .webp({ quality: 88, effort: 6 })
    .toFile(pathFromHere("../public/fanbar-icon-64.webp")),
  sharp(iconSource)
    .resize(64, 64)
    .png({ compressionLevel: 9, palette: true })
    .toFile(pathFromHere("../public/fanbar-icon-64.png")),
  sharp(iconSource)
    .resize(180, 180)
    .png({ compressionLevel: 9, palette: true })
    .toFile(pathFromHere("../public/apple-touch-icon.png")),
  sharp(iconSource)
    .resize(192, 192)
    .png({ compressionLevel: 9, palette: true })
    .toFile(pathFromHere("../public/icon-192.png")),
  sharp(iconSource)
    .resize(512, 512)
    .png({ compressionLevel: 9, palette: true })
    .toFile(pathFromHere("../public/icon-512.png")),
  ...Object.values(snapshot.images).flatMap((assets) =>
    Object.entries(assets).map(async ([screen, asset]) => {
      const source = await screenshotSource(asset);
      const output = pathFromHere(`../public${asset.src.replace(/\.webp$/, "")}`);
      // Retain the real window, transparent shadow, and original resolution.
      await sharp(source).webp({ quality: 88, effort: 6 }).toFile(`${output}.webp`);
      if (screen === "popover") {
        await Promise.all([
          sharp(source).avif({ quality: 65, effort: 6 }).toFile(`${output}.avif`),
          sharp(source).resize({ width: 456 }).avif({ quality: 65, effort: 6 }).toFile(`${output}-456.avif`),
          sharp(source).resize({ width: 456 }).webp({ quality: 88, effort: 6 }).toFile(`${output}-456.webp`),
        ]);
      }
    }),
  ),
]);
