// Rig playback core for render-rig-anim.ps1 (and for debugging: Add-Type -Path tools\RigAnim.cs).
using System;
public static class RigAnim {
    public static byte[] Lz(byte[] d) {
        int size = d[1] | (d[2] << 8) | (d[3] << 16); byte[] o = new byte[size]; int s = 4, t = 0;
        while (t < size) { int f = d[s++];
            for (int b = 7; b >= 0 && t < size; b--) {
                if (((f >> b) & 1) == 0) { o[t++] = d[s++]; continue; }
                int b1 = d[s], hi = b1 >> 4, b2 = d[s + 1], len, disp;
                if (hi == 0) { int b3 = d[s + 2]; len = ((b1 & 0xF) << 4) + (b2 >> 4) + 0x11; disp = (((b2 & 0xF) << 8) | b3) + 1; s += 3; }
                else if (hi == 1) { int b3 = d[s + 2], b4 = d[s + 3]; len = (((b1 & 0xF) << 12) | (b2 << 4) | (b3 >> 4)) + 0x111; disp = (((b3 & 0xF) << 8) | b4) + 1; s += 4; }
                else { len = hi + 1; disp = (((b1 & 0xF) << 8) | b2) + 1; s += 2; }
                for (int k = 0; k < len && t < size; k++) { o[t] = o[t - disp]; t++; } } }
        return o;
    }
    public static byte[] Unpack(byte[] d) { return (d.Length > 4 && d[0] == 0x11) ? Lz(d) : d; }
    static int U16(byte[] b, int o) { return BitConverter.ToUInt16(b, o); }
    static int S16(byte[] b, int o) { return BitConverter.ToInt16(b, o); }
    static int I32(byte[] b, int o) { return BitConverter.ToInt32(b, o); }
    // Returns the value offset (absolute) of sequence seq at local time t (looping), for an RNAN-style file.
    public static int ValueAt(byte[] a, int seq, int t, out int type) {
        int framesStart = U16(a, 0x20) + 0x18, valuesStart = U16(a, 0x24) + 0x18, h = 0x30 + 0x10 * seq;
        int fc = I32(a, h); type = U16(a, h + 4); int ss = I32(a, h + 0xC) + framesStart;
        int total = 0; for (int j = 0; j < fc; j++) total += U16(a, ss + 8 * j + 4);
        if (total > 0) t %= total; else t = 0;
        int j2 = 0; while (j2 < fc - 1 && t >= U16(a, ss + 8 * j2 + 4)) { t -= U16(a, ss + 8 * j2 + 4); j2++; }
        return I32(a, ss + 8 * j2) + valuesStart;
    }
    public static int SeqLength(byte[] a, int seq) {
        int framesStart = U16(a, 0x20) + 0x18, h = 0x30 + 0x10 * seq; int fc = I32(a, h), ss = I32(a, h + 0xC) + framesStart, total = 0;
        for (int j = 0; j < fc; j++) total += U16(a, ss + 8 * j + 4); return total;
    }
    // Multi-cell and its start time at global time T, from the RAMN (one sequence of u16 multi-cell values).
    public static int McAt(byte[] ramn, int T, out int local) {
        int framesStart = U16(ramn, 0x20) + 0x18, valuesStart = U16(ramn, 0x24) + 0x18;
        int fc = I32(ramn, 0x30), ss = I32(ramn, 0x3C) + framesStart, total = 0;
        for (int j = 0; j < fc; j++) total += U16(ramn, ss + 8 * j + 4);
        int t = total > 0 ? T % total : 0, k = 0;
        while (k < fc - 1 && t >= U16(ramn, ss + 8 * k + 4)) { t -= U16(ramn, ss + 8 * k + 4); k++; }
        local = t; return U16(ramn, I32(ramn, ss + 8 * k) + valuesStart);
    }
    // Renders palette indices into a size x size buffer, origin at (ox, oy).
    public static byte[] Frame(byte[] sheet, byte[] nanr, byte[] rcmn, byte[] cells, int mc, int t, int size, int ox, int oy, int rotSign) {
        byte[] img = new byte[size * size];
        int n = U16(rcmn, 0x2C + mc * 8), off = I32(rcmn, 0x30 + mc * 8);
        int[] order = new int[n], keys = new int[n];
        for (int i = 0; i < n; i++) { order[i] = i; keys[i] = -rcmn[0x3C + off + i * 8 + 7]; }
        Array.Sort(keys, order);
        foreach (int i in order) {
            int e = 0x3C + off + i * 8; int seq = U16(rcmn, e), rx = S16(rcmn, e + 2), ry = S16(rcmn, e + 4);
            int type; int vp = ValueAt(nanr, seq, t, out type);
            int cell = U16(nanr, vp); double rot = 0, sx = 1, sy = 1; int tx = 0, ty = 0;
            if (type == 1) { rot = U16(nanr, vp + 2) * 2 * Math.PI / 65536 * rotSign; sx = I32(nanr, vp + 4) / 4096.0; sy = I32(nanr, vp + 8) / 4096.0; tx = S16(nanr, vp + 0xC); ty = S16(nanr, vp + 0xE); }
            if (type == 2) { tx = S16(nanr, vp + 4); ty = S16(nanr, vp + 6); }
            int p = 12 + cell * 48;
            double X = I32(cells, p) / 256.0, Y = I32(cells, p + 4) / 256.0;
            int W = I32(cells, p + 8) / 4096, H = I32(cells, p + 12) / 4096, U = I32(cells, p + 16) / 4096, V = I32(cells, p + 20) / 4096;
            if (W <= 0 || H <= 0) continue;
            double px = ox + rx + tx, py = oy + ry + ty, c = Math.Cos(rot), s = Math.Sin(rot);
            int R = (int)Math.Ceiling(Math.Sqrt((Math.Abs(X) + W) * (Math.Abs(X) + W) + (Math.Abs(Y) + H) * (Math.Abs(Y) + H)) * Math.Max(Math.Abs(sx), Math.Abs(sy))) + 2;
            for (int y = (int)py - R; y <= (int)py + R; y++) { if (y < 0 || y >= size) continue;
                for (int x = (int)px - R; x <= (int)px + R; x++) { if (x < 0 || x >= size) continue;
                    double vx = x + 0.5 - px, vy = y + 0.5 - py;
                    double dx = (c * vx + s * vy) / sx, dy = (-s * vx + c * vy) / sy;   // inverse of [c -s; s c] * diag(sx, sy)
                    int u = (int)Math.Floor(dx - X), v = (int)Math.Floor(dy + Y);
                    if (u < 0 || u >= W || v < 0 || v >= H) continue;
                    int su = U + u, sv = V + v; if (su >= 256 || sv >= 128) continue;
                    int ii = sv * 256 + su, b = sheet[48 + ii / 2]; b = (ii % 2 == 0) ? (b & 0xF) : (b >> 4);
                    if (b != 0) img[y * size + x] = (byte)b; } }
        }
        return img;
    }
    // Zoomed ARGB pixels on a grass-green background with the shadow ellipse (28 x 6 px radii) under the origin.
    public static int[] Argb(byte[] buf, int[] pal, int size, int zoom, int ox, int oy) {
        int W = size * zoom; int[] o = new int[W * W];
        for (int y = 0; y < W; y++) for (int x = 0; x < W; x++) {
            int sx = x / zoom, sy = y / zoom, c = buf[sy * size + sx]; double ex = (sx + 0.5 - ox) / 28.0, ey = (sy + 0.5 - oy) / 6.0;
            o[y * W + x] = c != 0 ? pal[c] : (ex * ex + ey * ey <= 1 ? unchecked((int)0xFF609048) : unchecked((int)0xFF78A860)); }
        return o;
    }
}
