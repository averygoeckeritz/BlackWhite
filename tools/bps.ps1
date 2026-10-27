param([string]$Source, [string]$Target, [string]$Patch, [string]$Output, [switch]$Create, [switch]$Apply)
# BPS patch creator/applier (byuu's BPS1 format, as used by Rom Patcher JS, Floating IPS, Delta's recommended tools).
#   -Create: bps.ps1 -Create -Source original.nds -Target edited.nds -Patch out.bps
#   -Apply:  bps.ps1 -Apply  -Source original.nds -Patch out.bps -Output result.nds
# The encoder finds unchanged stretches (SourceRead when at the same offset, SourceCopy when shifted, found through
# a hash index of 256-byte source blocks) and stores everything else as raw TargetRead bytes.
Add-Type -TypeDefinition @"
using System; using System.Collections.Generic; using System.IO;
public static class Bps {
    static uint[] crcTable;
    static uint Crc32(byte[] d, int len) {
        if (crcTable == null) { crcTable = new uint[256]; for (uint i = 0; i < 256; i++) { uint c = i; for (int k = 0; k < 8; k++) c = (c & 1) != 0 ? 0xEDB88320u ^ (c >> 1) : c >> 1; crcTable[i] = c; } }
        uint crc = 0xFFFFFFFFu; for (int i = 0; i < len; i++) crc = crcTable[(crc ^ d[i]) & 0xFF] ^ (crc >> 8); return crc ^ 0xFFFFFFFFu;
    }
    static void WriteVar(List<byte> o, ulong data) { while (true) { byte x = (byte)(data & 0x7f); data >>= 7; if (data == 0) { o.Add((byte)(0x80 | x)); break; } o.Add(x); data--; } }
    static ulong ReadVar(byte[] p, ref int pos) { ulong data = 0, shift = 1; while (true) { byte x = p[pos++]; data += (ulong)(x & 0x7f) * shift; if ((x & 0x80) != 0) break; shift <<= 7; data += shift; } return data; }
    static ulong Hash(byte[] d, int pos, int k) { ulong h = 14695981039346656037UL; for (int i = 0; i < k; i++) { h ^= d[pos + i]; h *= 1099511628211UL; } return h; }
    public static string Create(string srcPath, string tgtPath, string patchPath) {
        byte[] src = File.ReadAllBytes(srcPath), tgt = File.ReadAllBytes(tgtPath);
        const int K = 256; var index = new Dictionary<ulong, int>();
        for (int i = 0; i + K <= src.Length; i += K) { ulong h = Hash(src, i, K); if (!index.ContainsKey(h)) index[h] = i; }
        var o = new List<byte>(1 << 20); o.AddRange(System.Text.Encoding.ASCII.GetBytes("BPS1"));
        WriteVar(o, (ulong)src.Length); WriteVar(o, (ulong)tgt.Length); WriteVar(o, 0);
        int t = 0; long srcRel = 0; var raw = new List<byte>(); int nRead = 0, nCopy = 0, nRaw = 0; long rawBytes = 0;
        Action flushRaw = () => { if (raw.Count > 0) { WriteVar(o, ((ulong)(raw.Count - 1) << 2) | 1); o.AddRange(raw); nRaw++; rawBytes += raw.Count; raw.Clear(); } };
        while (t < tgt.Length) {
            // 1. same-offset run
            int run = 0; while (t + run < src.Length && t + run < tgt.Length && src[t + run] == tgt[t + run]) run++;
            if (run >= 32) { flushRaw(); WriteVar(o, ((ulong)(run - 1) << 2) | 0); t += run; nRead++; continue; }
            // 2. shifted run via index
            int best = 0, bestS = -1;
            if (t + K <= tgt.Length) { int s; if (index.TryGetValue(Hash(tgt, t, K), out s)) { int len = 0; while (s + len < src.Length && t + len < tgt.Length && src[s + len] == tgt[t + len]) len++; if (len >= K) { best = len; bestS = s; } } }
            if (best > 0) {
                flushRaw(); WriteVar(o, ((ulong)(best - 1) << 2) | 2);
                long rel = bestS - srcRel; WriteVar(o, ((ulong)Math.Abs(rel) << 1) | (rel < 0 ? 1UL : 0UL)); srcRel = bestS + best; t += best; nCopy++; continue;
            }
            // 3. raw byte
            raw.Add(tgt[t]); t++;
        }
        flushRaw();
        uint cs = Crc32(src, src.Length), ct = Crc32(tgt, tgt.Length);
        o.AddRange(BitConverter.GetBytes(cs)); o.AddRange(BitConverter.GetBytes(ct));
        byte[] body = o.ToArray(); uint cp = Crc32(body, body.Length);
        using (var f = File.Create(patchPath)) { f.Write(body, 0, body.Length); f.Write(BitConverter.GetBytes(cp), 0, 4); }
        return string.Format("patch {0} bytes: {1} SourceRead, {2} SourceCopy, {3} TargetRead ({4} raw bytes); source crc {5:X8} target crc {6:X8}", body.Length + 4, nRead, nCopy, nRaw, rawBytes, cs, ct);
    }
    public static string Apply(string srcPath, string patchPath, string outPath) {
        byte[] src = File.ReadAllBytes(srcPath), p = File.ReadAllBytes(patchPath);
        if (p[0] != 'B' || p[1] != 'P' || p[2] != 'S' || p[3] != '1') throw new Exception("not a BPS1 patch");
        int pos = 4; ulong srcSize = ReadVar(p, ref pos), tgtSize = ReadVar(p, ref pos), metaSize = ReadVar(p, ref pos); pos += (int)metaSize;
        if ((ulong)src.Length != srcSize) throw new Exception("source size mismatch");
        byte[] tgt = new byte[tgtSize]; int t = 0; long srcRel = 0, tgtRel = 0; int end = p.Length - 12;
        while (pos < end) {
            ulong data = ReadVar(p, ref pos); int len = (int)(data >> 2) + 1; int cmd = (int)(data & 3);
            switch (cmd) {
                case 0: Array.Copy(src, t, tgt, t, len); t += len; break;
                case 1: Array.Copy(p, pos, tgt, t, len); pos += len; t += len; break;
                case 2: { ulong r = ReadVar(p, ref pos); srcRel += ((r & 1) != 0 ? -1 : 1) * (long)(r >> 1); Array.Copy(src, srcRel, tgt, t, len); srcRel += len; t += len; break; }
                case 3: { ulong r = ReadVar(p, ref pos); tgtRel += ((r & 1) != 0 ? -1 : 1) * (long)(r >> 1); for (int i = 0; i < len; i++) tgt[t++] = tgt[tgtRel++]; break; }
            }
        }
        uint cs = BitConverter.ToUInt32(p, p.Length - 12), ct = BitConverter.ToUInt32(p, p.Length - 8), cp = BitConverter.ToUInt32(p, p.Length - 4);
        if (Crc32(src, src.Length) != cs) throw new Exception("source CRC mismatch");
        if (Crc32(p, p.Length - 4) != cp) throw new Exception("patch CRC mismatch");
        uint got = Crc32(tgt, tgt.Length); if (got != ct) throw new Exception("target CRC mismatch: " + got.ToString("X8"));
        File.WriteAllBytes(outPath, tgt); return string.Format("applied: {0} bytes written, target crc {1:X8} OK", tgt.Length, ct);
    }
}
"@
if ($Create) { [Bps]::Create($Source, $Target, $Patch) }
elseif ($Apply) { [Bps]::Apply($Source, $Patch, $Output) }
else { "pass -Create or -Apply" }
