import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import zlib from "node:zlib";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const DIRS = ["down", "right", "left", "up"];

const SPRITES = [
  { id: "he_luo_fish", group: "enemy", colors: ["#244f68", "#4f91a8", "#8bc7cf", "#142733"], kind: "heluo" },
  { id: "fei_yi", group: "enemy", colors: ["#31325a", "#6d5f98", "#b09bd3", "#19182b"], kind: "feiyi" },
  { id: "zhuhuai", group: "enemy", colors: ["#3a2d29", "#6f5546", "#b59672", "#171210"], kind: "zhuhuai" },
  { id: "xiao_beast", group: "enemy", colors: ["#1f3440", "#4f7285", "#a7c9c7", "#101b20"], kind: "xiao" },
  { id: "elite_xiangliu_shadow", group: "entity", colors: ["#1d3025", "#4f7b49", "#9cc36f", "#0b1510"], kind: "xiangliu" },
  { id: "boss_zhulong_weak", group: "entity", colors: ["#49202c", "#9b3a3c", "#e59a64", "#170b10"], kind: "zhulong", tier: 0 },
  { id: "boss_zhulong", group: "entity", colors: ["#4c1720", "#c83b37", "#ffd26d", "#12070b"], kind: "zhulong", tier: 1 },
  { id: "boss_zhulong_strong", group: "entity", colors: ["#3b1022", "#e0483c", "#fff095", "#08050a"], kind: "zhulong", tier: 2 },
  { id: "dang_kang", group: "enemy", colors: ["#5a392b", "#a35f39", "#f2d18a", "#1b1110"], kind: "dangkang" },
  { id: "qiu_yu", group: "enemy", colors: ["#443651", "#8f7895", "#e8d7b1", "#15121d"], kind: "qiuyu" },
  { id: "ling_ling", group: "enemy", colors: ["#27301d", "#6e7b45", "#d8ca66", "#10140b"], kind: "lingling" },
  { id: "zhu_ru", group: "enemy", colors: ["#4c2734", "#b45e72", "#f0ad82", "#170b12"], kind: "zhuru" },
  { id: "elite_yinglong_young", group: "entity", colors: ["#173b48", "#3e9a8d", "#b9e4a7", "#07151a"], kind: "yinglong" },
  { id: "boss_qinglong_weak", group: "entity", colors: ["#123a35", "#237b72", "#a5df8d", "#041310"], kind: "qinglong", tier: 0 },
  { id: "boss_qinglong", group: "entity", colors: ["#0f3d3d", "#1ea48b", "#c8f48c", "#03110f"], kind: "qinglong", tier: 1 },
  { id: "boss_qinglong_strong", group: "entity", colors: ["#0a3037", "#17c39a", "#f0ff9d", "#020b0d"], kind: "qinglong", tier: 2 },
  { id: "kui", group: "enemy", colors: ["#3d342c", "#7a6544", "#d2b36a", "#15110d"], kind: "kui" },
  { id: "tu_lou", group: "enemy", colors: ["#4a3524", "#8f673f", "#d7b06e", "#18100b"], kind: "tulou" },
  { id: "jiao_beast", group: "enemy", colors: ["#382c24", "#a96b45", "#ead08a", "#130d0a"], kind: "jiao" },
  { id: "wen_lin", group: "enemy", colors: ["#273b34", "#66886d", "#c7c98a", "#0d1511"], kind: "wenlin" },
  { id: "elite_ji_meng", group: "entity", colors: ["#223d48", "#4d8f8d", "#b6cfa6", "#0b1519"], kind: "jimeng" },
  { id: "boss_qilin_weak", group: "entity", colors: ["#5b3a29", "#9b7650", "#d8c07c", "#1b100b"], kind: "qilin", tier: 0 },
  { id: "boss_qilin", group: "entity", colors: ["#604125", "#b58a51", "#e5d890", "#180f08"], kind: "qilin", tier: 1 },
  { id: "boss_qilin_strong", group: "entity", colors: ["#4b331f", "#c29b55", "#f0e69a", "#100a06"], kind: "qilin", tier: 2 },
];

function crc32(buf) {
  let c = ~0;
  for (let i = 0; i < buf.length; i++) {
    c ^= buf[i];
    for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xedb88320 & -(c & 1));
  }
  return ~c >>> 0;
}

function chunk(type, data) {
  const t = Buffer.from(type);
  const out = Buffer.alloc(12 + data.length);
  out.writeUInt32BE(data.length, 0);
  t.copy(out, 4);
  data.copy(out, 8);
  out.writeUInt32BE(crc32(Buffer.concat([t, data])), 8 + data.length);
  return out;
}

function writePng(file, w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    const row = y * (w * 4 + 1);
    raw[row] = 0;
    rgba.copy(raw, row + 1, y * w * 4, (y + 1) * w * 4);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8;
  ihdr[9] = 6;
  const png = Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk("IHDR", ihdr),
    chunk("IDAT", zlib.deflateSync(raw, { level: 9 })),
    chunk("IEND", Buffer.alloc(0)),
  ]);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, png);
}

function rgba(hex) {
  const x = hex.replace("#", "");
  return [parseInt(x.slice(0, 2), 16), parseInt(x.slice(2, 4), 16), parseInt(x.slice(4, 6), 16), 255];
}

class Canvas {
  constructor(w, h) {
    this.w = w;
    this.h = h;
    this.buf = Buffer.alloc(w * h * 4);
  }
  px(x, y, col) {
    x = Math.round(x);
    y = Math.round(y);
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return;
    const i = (y * this.w + x) * 4;
    this.buf[i] = col[0];
    this.buf[i + 1] = col[1];
    this.buf[i + 2] = col[2];
    this.buf[i + 3] = col[3];
  }
  ellipse(cx, cy, rx, ry, col) {
    const x0 = Math.floor(cx - rx), x1 = Math.ceil(cx + rx);
    const y0 = Math.floor(cy - ry), y1 = Math.ceil(cy + ry);
    for (let y = y0; y <= y1; y++) {
      for (let x = x0; x <= x1; x++) {
        const dx = (x - cx) / rx, dy = (y - cy) / ry;
        if (dx * dx + dy * dy <= 1) this.px(x, y, col);
      }
    }
  }
  poly(points, col) {
    const ys = points.map(p => p[1]);
    const y0 = Math.floor(Math.min(...ys)), y1 = Math.ceil(Math.max(...ys));
    for (let y = y0; y <= y1; y++) {
      const xs = [];
      for (let i = 0, j = points.length - 1; i < points.length; j = i++) {
        const a = points[i], b = points[j];
        if ((a[1] > y) !== (b[1] > y)) xs.push(a[0] + (y - a[1]) * (b[0] - a[0]) / (b[1] - a[1]));
      }
      xs.sort((a, b) => a - b);
      for (let i = 0; i < xs.length; i += 2) {
        for (let x = Math.ceil(xs[i]); x <= Math.floor(xs[i + 1]); x++) this.px(x, y, col);
      }
    }
  }
  line(x0, y0, x1, y1, thick, col) {
    const steps = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0), 1);
    for (let i = 0; i <= steps; i++) {
      const t = i / steps;
      this.ellipse(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, thick, thick, col);
    }
  }
  rect(x, y, w, h, col) {
    for (let yy = y; yy < y + h; yy++) for (let xx = x; xx < x + w; xx++) this.px(xx, yy, col);
  }
}

function stamp(dst, src, ox, oy) {
  for (let y = 0; y < src.h; y++) for (let x = 0; x < src.w; x++) {
    const si = (y * src.w + x) * 4;
    if (src.buf[si + 3] === 0) continue;
    const dx = ox + x, dy = oy + y;
    if (dx < 0 || dy < 0 || dx >= dst.w || dy >= dst.h) continue;
    src.buf.copy(dst.buf, (dy * dst.w + dx) * 4, si, si + 4);
  }
}

function scalePoints(points, s) {
  return points.map(p => [p[0] * s, p[1] * s]);
}

function renderSprite(spec, size, dir, frame) {
  const c = new Canvas(size, size);
  const s = size / 128;
  const [dark, mid, light, ink] = spec.colors.map(rgba);
  const accent = rgba(spec.tier === 2 ? "#a8f0ff" : "#ffd05d");
  const shadow = rgba("#0b1216");
  const sway = [0, 2, 0, -2][frame] * s;
  const side = dir === "right" ? 1 : dir === "left" ? -1 : 0;
  const back = dir === "up";
  const sx = x => x * s;
  const sy = y => y * s;

  c.ellipse(sx(64), sy(105), sx(24), sy(6), shadow);

  if (spec.kind === "heluo") {
    for (let i = 0; i < 10; i++) {
      const x = 30 + i * 7 + side * 4;
      const y = 72 + Math.sin((i + frame) * 0.9) * 5 + (back ? -4 : 0);
      c.line(sx(64), sy(68), sx(x), sy(y), sx(3), mid);
      c.line(sx(65), sy(68), sx(x + 3), sy(y + 2), sx(1.5), dark);
    }
    c.ellipse(sx(62 + side * 8), sy(58 + sway), sx(22), sy(16), mid);
    c.ellipse(sx(70 + side * 8), sy(54 + sway), sx(9), sy(8), light);
    c.ellipse(sx(73 + side * 9), sy(54 + sway), sx(2), sy(3), ink);
    c.poly(scalePoints([[76 + side * 8, 63], [90 + side * 12, 58], [90 + side * 12, 70]], s), dark);
    for (let i = 0; i < 4; i++) c.rect(sx(80 + side * 10), sy(61 + i * 2), Math.max(1, sx(2)), Math.max(1, sy(1)), light);
  } else if (spec.kind === "feiyi") {
    c.line(sx(64), sy(56 + sway), sx(28 - side * 10), sy(80), sx(8), dark);
    c.line(sx(64), sy(56 + sway), sx(100 + side * 10), sy(82), sx(8), dark);
    c.line(sx(64), sy(56 + sway), sx(28 - side * 10), sy(78), sx(5), mid);
    c.line(sx(64), sy(56 + sway), sx(100 + side * 10), sy(80), sx(5), mid);
    c.ellipse(sx(64 + side * 4), sy(50 + sway), sx(16), sy(12), mid);
    c.ellipse(sx(58 + side * 5), sy(48 + sway), sx(2), sy(3), light);
    c.ellipse(sx(70 + side * 5), sy(48 + sway), sx(2), sy(3), light);
    c.poly(scalePoints([[45, 91], [31, 82], [49, 80]], s), light);
    c.poly(scalePoints([[83, 91], [101, 82], [79, 80]], s), light);
  } else if (spec.kind === "zhuhuai") {
    c.ellipse(sx(63 + side * 4), sy(70), sx(29), sy(20), mid);
    c.ellipse(sx(58 + side * 7), sy(50 + sway), sx(19), sy(16), mid);
    c.poly(scalePoints([[43 + side * 5, 39], [35 + side * 2, 23], [51 + side * 8, 36]], s), light);
    c.poly(scalePoints([[57 + side * 5, 35], [54 + side * 5, 18], [66 + side * 5, 35]], s), light);
    c.poly(scalePoints([[69 + side * 5, 36], [82 + side * 8, 22], [78 + side * 4, 40]], s), light);
    c.poly(scalePoints([[79 + side * 4, 43], [96 + side * 8, 34], [86 + side * 6, 52]], s), light);
    c.ellipse(sx(55 + side * 6), sy(49 + sway), sx(5), sy(4), light);
    c.ellipse(sx(56 + side * 6), sy(49 + sway), sx(2), sy(2), ink);
    for (const x of [45, 58, 73, 86]) c.line(sx(x), sy(86), sx(x + side * 3), sy(103), sx(4), dark);
  } else if (spec.kind === "xiao") {
    c.ellipse(sx(64 + side * 5), sy(61 + sway), sx(13), sy(17), mid);
    c.ellipse(sx(64 + side * 5), sy(53 + sway), sx(8), sy(7), light);
    c.ellipse(sx(64 + side * 5), sy(53 + sway), sx(3), sy(4), ink);
    const lift = frame % 2 === 0 ? 0 : -8;
    c.poly(scalePoints([[56, 61], [19, 40 + lift], [48, 76]], s), dark);
    c.poly(scalePoints([[72, 61], [110, 42 + lift], [80, 76]], s), dark);
    c.poly(scalePoints([[59, 69], [28, 88 - lift], [58, 82]], s), mid);
    c.poly(scalePoints([[69, 69], [101, 88 - lift], [70, 82]], s), mid);
    c.line(sx(64), sy(77), sx(82 + side * 9), sy(95), sx(3), light);
  } else if (spec.kind === "xiangliu") {
    c.ellipse(sx(64), sy(76), sx(30), sy(18), dark);
    for (let i = 0; i < 9; i++) {
      const a = (-120 + i * 30 + side * 8) * Math.PI / 180;
      const hx = 64 + Math.cos(a) * (25 + (i % 2) * 6);
      const hy = 60 + Math.sin(a) * 18 + Math.sin(frame + i) * 2;
      c.line(sx(64), sy(70), sx(hx), sy(hy), sx(4), mid);
      c.ellipse(sx(hx), sy(hy), sx(6), sy(5), light);
      c.ellipse(sx(hx + 1), sy(hy - 1), sx(1.3), sy(1.5), ink);
    }
    c.line(sx(48), sy(83), sx(27 - side * 8), sy(95), sx(6), dark);
    c.line(sx(79), sy(82), sx(101 + side * 8), sy(94), sx(6), dark);
    c.ellipse(sx(64), sy(94), sx(20), sy(5), rgba("#365334"));
  } else if (spec.kind === "zhulong") {
    const tier = spec.tier ?? 0;
    c.line(sx(34), sy(86), sx(52 + side * 8), sy(64 + sway), sx(11 + tier * 2), dark);
    c.line(sx(52 + side * 8), sy(64 + sway), sx(83 + side * 8), sy(70), sx(12 + tier * 2), mid);
    c.line(sx(83 + side * 8), sy(70), sx(101 + side * 4), sy(88), sx(10 + tier * 2), dark);
    c.ellipse(sx(67 + side * 7), sy(47 + sway), sx(18 + tier * 2), sy(15 + tier), mid);
    c.ellipse(sx(65 + side * 7), sy(47 + sway), sx(10), sy(11), rgba("#c98b73"));
    c.rect(sx(63 + side * 7), sy(42 + sway), Math.max(1, sx(3)), Math.max(1, sy(10)), tier === 0 ? dark : accent);
    c.rect(sx(70 + side * 7), sy(42 + sway), Math.max(1, sx(3)), Math.max(1, sy(10)), tier === 0 ? accent : dark);
    c.poly(scalePoints([[55 + side * 7, 34], [45 + side * 4, 21 - tier * 3], [62 + side * 7, 33]], s), light);
    c.poly(scalePoints([[76 + side * 7, 34], [90 + side * 8, 22 - tier * 3], [81 + side * 7, 36]], s), light);
    for (let i = 0; i < 7 + tier * 3; i++) {
      c.rect(sx(43 + i * 7 + side * 6), sy(62 + ((i + frame) % 2) * 3), Math.max(1, sx(3)), Math.max(1, sy(2)), light);
    }
    if (tier >= 1) c.line(sx(35), sy(40), sx(96), sy(28 + sway), sx(1.5 + tier), accent);
    if (tier >= 2) {
      c.line(sx(29), sy(96), sx(103), sy(37), sx(1.5), rgba("#80d9f0"));
      c.line(sx(100), sy(92), sx(37), sy(33), sx(1.5), rgba("#ffd05d"));
    }
  } else if (spec.kind === "dangkang") {
    c.ellipse(sx(66 + side * 4), sy(72), sx(30), sy(19), mid);
    c.ellipse(sx(47 + side * 13), sy(56 + sway), sx(18), sy(14), mid);
    c.ellipse(sx(40 + side * 16), sy(59 + sway), sx(9), sy(7), dark);
    c.rect(sx(36 + side * 16), sy(58 + sway), Math.max(1, sx(3)), Math.max(1, sy(2)), light);
    c.rect(sx(43 + side * 16), sy(58 + sway), Math.max(1, sx(3)), Math.max(1, sy(2)), light);
    c.poly(scalePoints([[36 + side * 14, 50], [25 + side * 13, 39], [42 + side * 15, 47]], s), dark);
    c.poly(scalePoints([[54 + side * 13, 47], [65 + side * 17, 35], [61 + side * 13, 52]], s), dark);
    c.poly(scalePoints([[37 + side * 17, 65], [27 + side * 18, 76], [44 + side * 17, 68]], s), light);
    c.poly(scalePoints([[48 + side * 14, 65], [61 + side * 14, 76], [53 + side * 14, 66]], s), light);
    c.ellipse(sx(52 + side * 14), sy(52 + sway), sx(2.2), sy(2.2), ink);
    for (const x of [43, 57, 74, 87]) c.line(sx(x), sy(86), sx(x + side * 2), sy(104), sx(4), ink);
    for (let i = 0; i < 5; i++) c.rect(sx(58 + i * 7), sy(51 + (i % 2) * 2), Math.max(1, sx(3)), Math.max(1, sy(5)), dark);
    c.line(sx(91), sy(66), sx(105 + side * 5), sy(57 + sway), sx(3), light);
  } else if (spec.kind === "qiuyu") {
    c.ellipse(sx(62 + side * 4), sy(72), sx(23), sy(16), mid);
    c.ellipse(sx(49 + side * 10), sy(54 + sway), sx(14), sy(12), mid);
    c.poly(scalePoints([[43 + side * 10, 46], [38 + side * 8, 26], [51 + side * 11, 44]], s), light);
    c.poly(scalePoints([[53 + side * 10, 44], [57 + side * 12, 25], [61 + side * 11, 47]], s), light);
    c.poly(scalePoints([[59 + side * 10, 55], [79 + side * 15, 48], [63 + side * 11, 62]], s), dark);
    c.ellipse(sx(45 + side * 11), sy(53 + sway), sx(4.2), sy(5), light);
    c.ellipse(sx(55 + side * 10), sy(53 + sway), sx(4.2), sy(5), light);
    c.ellipse(sx(45 + side * 11), sy(53 + sway), sx(1.7), sy(2.2), ink);
    c.ellipse(sx(55 + side * 10), sy(53 + sway), sx(1.7), sy(2.2), ink);
    c.poly(scalePoints([[57 + side * 10, 58], [70 + side * 14, 55], [59 + side * 10, 62]], s), light);
    c.line(sx(82), sy(73), sx(102 + side * 7), sy(88), sx(5), ink);
    c.line(sx(102 + side * 7), sy(88), sx(93 + side * 5), sy(100), sx(3), light);
    for (const x of [49, 72]) c.line(sx(x), sy(85), sx(x + side * 2), sy(101), sx(3), dark);
  } else if (spec.kind === "lingling") {
    c.ellipse(sx(66 + side * 3), sy(72), sx(32), sy(20), mid);
    c.ellipse(sx(50 + side * 9), sy(53 + sway), sx(19), sy(15), mid);
    c.poly(scalePoints([[39 + side * 8, 42], [31 + side * 5, 25], [49 + side * 9, 41]], s), light);
    c.poly(scalePoints([[61 + side * 8, 42], [74 + side * 12, 25], [69 + side * 9, 43]], s), light);
    c.ellipse(sx(52 + side * 10), sy(52 + sway), sx(2.5), sy(2.5), ink);
    for (let i = 0; i < 6; i++) {
      const stripeX = 43 + i * 8;
      c.line(sx(stripeX), sy(57 + (i % 2) * 2), sx(stripeX + 5), sy(78 + (i % 3) * 2), sx(2.2), ink);
    }
    c.line(sx(35), sy(47), sx(24), sy(43 + frame), sx(2), light);
    c.line(sx(75), sy(47), sx(88), sy(43 - frame), sx(2), light);
    for (const x of [43, 58, 75, 90]) c.line(sx(x), sy(87), sx(x + side * 2), sy(104), sx(4), dark);
    c.line(sx(88), sy(65), sx(105 + side * 4), sy(63 + sway), sx(3), ink);
  } else if (spec.kind === "zhuru") {
    c.ellipse(sx(63 + side * 4), sy(70), sx(24), sy(15), mid);
    c.ellipse(sx(48 + side * 10), sy(52 + sway), sx(14), sy(12), mid);
    c.poly(scalePoints([[41 + side * 10, 43], [36 + side * 8, 27], [51 + side * 10, 44]], s), light);
    c.poly(scalePoints([[54 + side * 10, 44], [62 + side * 13, 29], [61 + side * 10, 48]], s), light);
    c.poly(scalePoints([[39 + side * 12, 57], [26 + side * 14, 60], [42 + side * 12, 64]], s), light);
    c.poly(scalePoints([[57, 65], [26, 51 - frame * 2], [52, 79]], s), dark);
    c.poly(scalePoints([[70, 65], [104, 51 - frame * 2], [76, 79]], s), dark);
    for (let i = 0; i < 4; i++) {
      c.line(sx(36 + i * 6), sy(55 - frame * 2 + i), sx(51 + i * 3), sy(72 + i), sx(1.2), light);
      c.line(sx(94 - i * 6), sy(55 - frame * 2 + i), sx(76 - i * 3), sy(72 + i), sx(1.2), light);
    }
    c.ellipse(sx(52 + side * 10), sy(51 + sway), sx(2.2), sy(2.2), ink);
    c.line(sx(83), sy(72), sx(103 + side * 4), sy(83), sx(4), light);
    c.line(sx(102 + side * 4), sy(83), sx(108 + side * 5), sy(76), sx(2), dark);
  } else if (spec.kind === "yinglong") {
    c.line(sx(26), sy(87), sx(45 + side * 4), sy(74 + sway), sx(7), ink);
    c.line(sx(45 + side * 4), sy(74 + sway), sx(72 + side * 8), sy(63), sx(9), mid);
    c.line(sx(72 + side * 8), sy(63), sx(95 + side * 8), sy(77), sx(7), dark);
    c.ellipse(sx(62 + side * 8), sy(47 + sway), sx(16), sy(12), mid);
    c.poly(scalePoints([[51, 60], [16, 32 - frame * 3], [46, 75]], s), dark);
    c.poly(scalePoints([[75, 60], [113, 33 - frame * 3], [82, 75]], s), dark);
    c.line(sx(25), sy(38 - frame * 3), sx(48), sy(67), sx(2), light);
    c.line(sx(104), sy(38 - frame * 3), sx(80), sy(67), sx(2), light);
    c.poly(scalePoints([[50 + side * 8, 38], [40 + side * 5, 22], [58 + side * 8, 38]], s), light);
    c.poly(scalePoints([[70 + side * 8, 38], [84 + side * 9, 23], [76 + side * 8, 40]], s), light);
    c.line(sx(56 + side * 8), sy(56 + sway), sx(41 + side * 4), sy(67), sx(3), light);
    c.line(sx(74 + side * 8), sy(60), sx(88 + side * 7), sy(69), sx(3), light);
    c.ellipse(sx(67 + side * 8), sy(46 + sway), sx(2.2), sy(2.2), ink);
    c.line(sx(49 + side * 9), sy(50 + sway), sx(35 + side * 8), sy(53 + sway), sx(1.3), light);
  } else if (spec.kind === "qinglong") {
    const tier = spec.tier ?? 0;
    const body = [
      [20, 88],
      [36 + side * 2, 78 + sway],
      [52 + side * 5, 83 - sway],
      [66 + side * 7, 68 + sway],
      [83 + side * 8, 64],
    ];
    for (let i = 0; i < body.length - 1; i++) {
      const a = body[i], b = body[i + 1];
      c.line(sx(a[0]), sy(a[1]), sx(b[0]), sy(b[1]), sx(12 + tier * 2), ink);
      c.line(sx(a[0]), sy(a[1] - 2), sx(b[0]), sy(b[1] - 2), sx(7 + tier), i % 2 === 0 ? dark : mid);
    }
    c.ellipse(sx(82 + side * 8), sy(50 + sway), sx(21 + tier * 2), sy(14 + tier), mid);
    c.poly(scalePoints([[96 + side * 8, 49], [113 + side * 12, 43], [101 + side * 8, 58]], s), mid);
    c.poly(scalePoints([[72 + side * 8, 39], [58 + side * 5, 18 - tier * 2], [80 + side * 8, 38]], s), light);
    c.poly(scalePoints([[88 + side * 8, 38], [103 + side * 10, 18 - tier * 2], [94 + side * 8, 40]], s), light);
    c.poly(scalePoints([[101 + side * 8, 55], [114 + side * 12, 57], [101 + side * 8, 62]], s), light);
    c.ellipse(sx(91 + side * 8), sy(47 + sway), sx(3.2), sy(3.2), rgba("#f0ff9d"));
    c.line(sx(74 + side * 8), sy(50 + sway), sx(54 + side * 5), sy(52 + sway), sx(1.5 + tier * 0.3), light);
    c.line(sx(78 + side * 8), sy(57 + sway), sx(58 + side * 5), sy(69), sx(1.3 + tier * 0.3), light);
    c.line(sx(102 + side * 8), sy(52 + sway), sx(119 + side * 10), sy(44 + sway), sx(1.2), light);
    c.line(sx(102 + side * 8), sy(58 + sway), sx(119 + side * 10), sy(67 + sway), sx(1.2), light);
    for (let i = 0; i < 8 + tier * 2; i++) {
      const px = 30 + i * 7 + side * 4;
      c.poly(scalePoints([[px, 67 + ((i + frame) % 2) * 4], [px + 4, 62 + ((i + frame) % 2) * 4], [px + 7, 68 + ((i + frame) % 2) * 4]], s), light);
    }
    for (const claw of [[48, 76], [72, 78], [87, 82]]) {
      c.line(sx(claw[0] + side * 3), sy(claw[1]), sx(claw[0] + side * 1), sy(claw[1] + 15), sx(2.2), light);
      c.line(sx(claw[0] + side * 1), sy(claw[1] + 15), sx(claw[0] - 7 + side), sy(claw[1] + 18), sx(1.5), light);
    }
    c.line(sx(28), sy(40), sx(61), sy(31 + sway), sx(1.2 + tier * 0.4), rgba("#a8f0c0"));
    c.line(sx(92), sy(30), sx(116), sy(25 + sway), sx(1.2 + tier * 0.4), rgba("#a8f0c0"));
    if (tier >= 1) c.line(sx(42), sy(98), sx(66), sy(84), sx(1.2), rgba("#d9ff9b"));
    if (tier >= 2) c.line(sx(104), sy(28), sx(95), sy(43), sx(1.4), rgba("#eaff9d"));
  } else if (spec.kind === "kui") {
    c.ellipse(sx(64 + side * 4), sy(69), sx(30), sy(20), mid);
    c.ellipse(sx(50 + side * 10), sy(51 + sway), sx(18), sy(15), mid);
    c.poly(scalePoints([[43 + side * 10, 43], [34 + side * 8, 31], [53 + side * 10, 42]], s), light);
    c.ellipse(sx(54 + side * 10), sy(50 + sway), sx(2.6), sy(2.6), ink);
    c.line(sx(61), sy(84), sx(61 + side * 2), sy(105), sx(7), ink);
    c.line(sx(82), sy(75), sx(101 + side * 6), sy(83), sx(6), dark);
    c.line(sx(38), sy(36), sx(22), sy(27 + sway), sx(1.8), accent);
    c.line(sx(87), sy(34), sx(108), sy(27 - sway), sx(1.8), accent);
  } else if (spec.kind === "tulou") {
    c.ellipse(sx(64 + side * 4), sy(72), sx(30), sy(19), mid);
    c.ellipse(sx(48 + side * 11), sy(54 + sway), sx(17), sy(13), mid);
    for (const horn of [[39, 42, 29, 25], [49, 39, 44, 22], [56, 39, 64, 22], [64, 43, 78, 27]]) {
      c.poly(scalePoints([[horn[0] + side * 10, horn[1]], [horn[2] + side * 10, horn[3]], [horn[0] + side * 11, horn[1] + 7]], s), light);
    }
    c.ellipse(sx(51 + side * 11), sy(53 + sway), sx(2.2), sy(2.2), ink);
    for (const x of [43, 58, 75, 90]) c.line(sx(x), sy(87), sx(x + side * 2), sy(104), sx(4), ink);
  } else if (spec.kind === "jiao") {
    c.ellipse(sx(64 + side * 4), sy(71), sx(28), sy(17), mid);
    c.ellipse(sx(48 + side * 11), sy(53 + sway), sx(16), sy(12), mid);
    c.poly(scalePoints([[39 + side * 11, 42], [32 + side * 9, 24], [48 + side * 11, 41]], s), light);
    c.poly(scalePoints([[57 + side * 11, 41], [68 + side * 14, 24], [64 + side * 11, 45]], s), light);
    for (let i = 0; i < 7; i++) c.ellipse(sx(48 + i * 7), sy(62 + (i % 2) * 8), sx(2.2), sy(2.2), ink);
    c.ellipse(sx(52 + side * 11), sy(52 + sway), sx(2.2), sy(2.2), ink);
    c.line(sx(86), sy(72), sx(106 + side * 6), sy(63), sx(3), light);
    for (const x of [45, 60, 78, 91]) c.line(sx(x), sy(86), sx(x + side * 2), sy(103), sx(3.5), dark);
  } else if (spec.kind === "wenlin") {
    c.ellipse(sx(64 + side * 4), sy(74), sx(27), sy(14), mid);
    c.ellipse(sx(49 + side * 10), sy(57 + sway), sx(14), sy(10), mid);
    c.line(sx(58), sy(61), sx(88 + side * 6), sy(50 + sway), sx(3), light);
    for (let i = 0; i < 8; i++) c.poly(scalePoints([[39 + i * 7, 66], [42 + i * 7, 62], [45 + i * 7, 67], [42 + i * 7, 71]], s), i % 2 ? light : dark);
    c.ellipse(sx(52 + side * 10), sy(56 + sway), sx(2), sy(2), ink);
    for (const x of [48, 64, 80]) c.line(sx(x), sy(84), sx(x + side * 2), sy(100), sx(3), dark);
  } else if (spec.kind === "jimeng") {
    c.ellipse(sx(64), sy(73), sx(19), sy(24), mid);
    c.ellipse(sx(63 + side * 8), sy(46 + sway), sx(17), sy(13), mid);
    c.poly(scalePoints([[75 + side * 8, 45], [98 + side * 12, 39], [80 + side * 8, 55]], s), dark);
    c.poly(scalePoints([[54 + side * 8, 36], [43 + side * 6, 20], [62 + side * 8, 37]], s), light);
    c.poly(scalePoints([[69 + side * 8, 35], [84 + side * 9, 20], [76 + side * 8, 38]], s), light);
    c.ellipse(sx(68 + side * 8), sy(45 + sway), sx(2.5), sy(2.5), ink);
    c.line(sx(48), sy(68), sx(31 - side * 3), sy(85), sx(4), dark);
    c.line(sx(80), sy(68), sx(98 + side * 3), sy(85), sx(4), dark);
    for (let i = 0; i < 4; i++) c.line(sx(31 + i * 18), sy(30), sx(26 + i * 18), sy(88), sx(1), light);
  } else if (spec.kind === "qilin") {
    const tier = spec.tier ?? 0;
    c.ellipse(sx(65 + side * 4), sy(70), sx(31 + tier * 2), sy(18 + tier), mid);
    c.ellipse(sx(49 + side * 12), sy(50 + sway), sx(18 + tier), sy(13 + tier), mid);
    c.poly(scalePoints([[42 + side * 12, 38], [35 + side * 10, 20 - tier * 3], [50 + side * 12, 39]], s), light);
    c.poly(scalePoints([[54 + side * 12, 37], [58 + side * 13, 16 - tier * 4], [64 + side * 12, 42]], s), accent);
    c.poly(scalePoints([[60 + side * 12, 40], [73 + side * 15, 25 - tier * 2], [68 + side * 12, 44]], s), light);
    for (let i = 0; i < 7 + tier * 2; i++) c.poly(scalePoints([[43 + i * 8, 59 + (i % 2) * 6], [47 + i * 8, 55 + (i % 2) * 6], [51 + i * 8, 60 + (i % 2) * 6]], s), light);
    c.ellipse(sx(52 + side * 12), sy(49 + sway), sx(2.5), sy(2.5), ink);
    c.line(sx(88), sy(69), sx(108 + side * 6), sy(54 + sway), sx(4), light);
    for (const x of [43, 58, 75, 91]) c.line(sx(x), sy(85), sx(x + side * 2), sy(104), sx(4), ink);
    if (tier >= 1) c.line(sx(31), sy(39), sx(100), sy(28 + sway), sx(1.3), rgba("#e7d98a"));
    if (tier >= 2) c.line(sx(28), sy(95), sx(106), sy(34), sx(1.4), rgba("#b6d3aa"));
  }
  return c;
}

function renderSheet(spec, size) {
  const sheet = new Canvas(size * 4, size * 4);
  for (let r = 0; r < 4; r++) {
    for (let f = 0; f < 4; f++) stamp(sheet, renderSprite(spec, size, DIRS[r], f), f * size, r * size);
  }
  return sheet;
}

function outPaths(spec) {
  const isoDir = spec.group === "enemy" ? "assets/textures/iso/enemies" : "assets/textures/iso/entities";
  return {
    iso: path.join(ROOT, isoDir, `${spec.id}_walk.png`),
    top: path.join(ROOT, "assets/textures/top/entities", `${spec.id}.png`),
  };
}

for (const spec of SPRITES) {
  const iso = renderSheet(spec, 128);
  const top = renderSheet(spec, 48);
  const files = outPaths(spec);
  writePng(files.iso, iso.w, iso.h, iso.buf);
  writePng(files.top, top.w, top.h, top.buf);
  console.log(`generated ${path.relative(ROOT, files.iso)} and ${path.relative(ROOT, files.top)}`);
}
