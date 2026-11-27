/**
 * Removes hidden metadata from uploaded chat images (Run 091).
 *
 * Photos carry details that can identify an "anonymous" sender: GPS
 * location, camera make and serial, capture time, author and software
 * names, embedded thumbnails. This rewrites the file without them, using
 * only the container formats (no image decoding, no native dependency):
 *
 * - JPEG: drops APP1 (EXIF/XMP), APP3-APP13, APP15 and comment segments.
 *   Keeps APP0 (JFIF), APP2 (ICC colour profile) and APP14 (Adobe colour
 *   transform), which carry no personal data. If the EXIF orientation was
 *   not "normal", a minimal EXIF block holding ONLY the orientation is
 *   written back so phone photos are not shown sideways.
 * - PNG: drops tEXt, zTXt, iTXt, eXIf and tIME chunks.
 * - WebP: drops EXIF and XMP chunks and clears their VP8X flags.
 *
 * Anything that does not parse cleanly is refused rather than passed on.
 */

export class ImageStripError extends Error {}

const fail = (why: string): never => {
  throw new ImageStripError(why);
};

// --- JPEG -----------------------------------------------------------------

const JPEG_KEEP_APP = new Set([0xe0, 0xe2, 0xee]); // APP0, APP2, APP14

/** EXIF orientation (1-8) from an APP1 payload, or null. */
function exifOrientation(seg: Buffer): number | null {
  // seg = "Exif\0\0" + TIFF
  if (seg.length < 14 || seg.subarray(0, 6).toString('latin1') !== 'Exif\0\0') return null;
  const tiff = seg.subarray(6);
  const order = tiff.subarray(0, 2).toString('latin1');
  const le = order === 'II';
  if (!le && order !== 'MM') return null;
  const u16 = (o: number) => (le ? tiff.readUInt16LE(o) : tiff.readUInt16BE(o));
  const u32 = (o: number) => (le ? tiff.readUInt32LE(o) : tiff.readUInt32BE(o));
  try {
    const ifd = u32(4);
    const count = u16(ifd);
    for (let i = 0; i < count; i++) {
      const entry = ifd + 2 + i * 12;
      if (u16(entry) === 0x0112) {
        const value = u16(entry + 8);
        return value >= 1 && value <= 8 ? value : null;
      }
    }
  } catch {
    return null;
  }
  return null;
}

/** A minimal big-endian EXIF APP1 segment holding only the orientation. */
function orientationOnlyApp1(orientation: number): Buffer {
  const tiff = Buffer.alloc(26);
  tiff.write('MM', 0, 'latin1');
  tiff.writeUInt16BE(42, 2);
  tiff.writeUInt32BE(8, 4); // IFD0 offset
  tiff.writeUInt16BE(1, 8); // one entry
  tiff.writeUInt16BE(0x0112, 10); // Orientation
  tiff.writeUInt16BE(3, 12); // SHORT
  tiff.writeUInt32BE(1, 14); // count
  tiff.writeUInt16BE(orientation, 18);
  tiff.writeUInt32BE(0, 22); // no next IFD
  const payload = Buffer.concat([Buffer.from('Exif\0\0', 'latin1'), tiff]);
  const header = Buffer.from([0xff, 0xe1, 0, 0]);
  header.writeUInt16BE(payload.length + 2, 2);
  return Buffer.concat([header, payload]);
}

function stripJpeg(input: Buffer): Buffer {
  if (input[0] !== 0xff || input[1] !== 0xd8) fail('not a JPEG');
  const parts: Buffer[] = [input.subarray(0, 2)];
  let orientation: number | null = null;
  let pos = 2;
  for (;;) {
    if (pos + 4 > input.length) fail('truncated JPEG');
    if (input[pos] !== 0xff) fail('bad JPEG marker');
    const marker = input[pos + 1];
    if (marker === 0xff) {
      pos += 1; // fill byte
      continue;
    }
    if (marker === 0xd9) fail('JPEG has no image data');
    const length = input.readUInt16BE(pos + 2);
    if (length < 2 || pos + 2 + length > input.length) fail('bad JPEG segment');
    const segment = input.subarray(pos, pos + 2 + length);
    if (marker === 0xda) {
      // Start of scan: the rest is compressed image data; copy it as is.
      if (orientation !== null && orientation !== 1) {
        parts.splice(1, 0, orientationOnlyApp1(orientation));
      }
      parts.push(input.subarray(pos));
      return Buffer.concat(parts);
    }
    const isApp = marker >= 0xe0 && marker <= 0xef;
    if (marker === 0xe1) {
      orientation ??= exifOrientation(segment.subarray(4));
    }
    const drop = marker === 0xfe || (isApp && !JPEG_KEEP_APP.has(marker));
    if (!drop) parts.push(segment);
    pos += 2 + length;
  }
}

// --- PNG ------------------------------------------------------------------

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const PNG_DROP = new Set(['tEXt', 'zTXt', 'iTXt', 'eXIf', 'tIME']);

function stripPng(input: Buffer): Buffer {
  if (!input.subarray(0, 8).equals(PNG_SIGNATURE)) fail('not a PNG');
  const parts: Buffer[] = [PNG_SIGNATURE];
  let pos = 8;
  let sawEnd = false;
  while (pos < input.length) {
    if (pos + 12 > input.length) fail('truncated PNG');
    const length = input.readUInt32BE(pos);
    const type = input.subarray(pos + 4, pos + 8).toString('latin1');
    const end = pos + 12 + length;
    if (end > input.length) fail('bad PNG chunk');
    if (!PNG_DROP.has(type)) parts.push(input.subarray(pos, end));
    pos = end;
    if (type === 'IEND') {
      sawEnd = true;
      break;
    }
  }
  if (!sawEnd) fail('PNG has no end');
  return Buffer.concat(parts);
}

// --- WebP -----------------------------------------------------------------

function stripWebp(input: Buffer): Buffer {
  if (
    input.length < 12 ||
    input.subarray(0, 4).toString('latin1') !== 'RIFF' ||
    input.subarray(8, 12).toString('latin1') !== 'WEBP'
  ) {
    fail('not a WebP');
  }
  const chunks: Buffer[] = [];
  let pos = 12;
  const riffEnd = Math.min(input.length, 8 + input.readUInt32LE(4));
  while (pos + 8 <= riffEnd) {
    const type = input.subarray(pos, pos + 4).toString('latin1');
    const size = input.readUInt32LE(pos + 4);
    const end = pos + 8 + size + (size % 2);
    if (pos + 8 + size > input.length) fail('bad WebP chunk');
    if (type !== 'EXIF' && type !== 'XMP ') {
      const chunk = Buffer.from(input.subarray(pos, Math.min(end, input.length)));
      if (type === 'VP8X' && chunk.length >= 9) {
        chunk[8] &= ~(0x08 | 0x04); // clear the EXIF and XMP flags
      }
      chunks.push(chunk);
    }
    pos = end;
  }
  if (chunks.length === 0) fail('WebP has no image data');
  const body = Buffer.concat(chunks);
  const header = Buffer.alloc(12);
  header.write('RIFF', 0, 'latin1');
  header.writeUInt32LE(body.length + 4, 4);
  header.write('WEBP', 8, 'latin1');
  return Buffer.concat([header, body]);
}

export function stripImageMetadata(
  bytes: Buffer,
  type: 'image/png' | 'image/jpeg' | 'image/webp',
): Buffer {
  switch (type) {
    case 'image/jpeg':
      return stripJpeg(bytes);
    case 'image/png':
      return stripPng(bytes);
    case 'image/webp':
      return stripWebp(bytes);
  }
}
