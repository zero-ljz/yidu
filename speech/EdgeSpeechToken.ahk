; Edge Read Aloud Sec-MS-GEC v2 protocol helper.
; Adapted from edge-tts src/edge_tts/drm.py, Copyright (c) rany.
; This file is licensed under LGPL-3.0-only; see ../third-party/edge-tts-LICENSE.txt
; and ../third-party/GPL-3.0.txt. The rest of YiDu retains its MIT license.
; https://github.com/rany2/edge-tts/blob/master/src/edge_tts/drm.py

BuildEdgeSpeechTokenCSharp()
{
    return '
(
public static class EdgeSpeechToken
{
    private static readonly uint[] Initial = {
        0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A,
        0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19
    };
    private static readonly uint[] Constants = {
        0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5, 0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
        0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3, 0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
        0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC, 0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
        0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7, 0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
        0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13, 0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
        0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3, 0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
        0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5, 0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
        0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208, 0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2
    };
    private static readonly uint[] ScheduleSeed = {
        0xEB24BF9E, 0x1558691F, 0xA0C09EE2, 0x0CFA32BA, 0xA622EE8C, 0xD1DD9491, 0xC0DD25A0,
        0xF9E70AB6, 0xF0C31573, 0x7058CE4E, 0x7188E606, 0x00E5AB33, 0xD258B060, 0x72766564
    };
    private static readonly uint[] CsCoefficients = {
        0xE82E91B1, 0x44DE24C6, 0x3BEB65BC, 0xC89C5933, 0x8D1EC211, 0x314EF5D5, 0xE92491B1,
        0xF0A5B9D5, 0x06064CF3, 0xDA79FA60, 0xBED20560, 0x89F9C9F8, 0x35FA38C6, 0xCB49E3C6
    };
    private static readonly uint[] CsOffsets = {
        0xB32700D0, 0x88DFF51D, 0x29514038, 0xB328CBDF, 0xD405B4D5, 0x26E55F3C, 0x607801C6,
        0x82B2C1FB, 0xFA51A3DA, 0x207CC464, 0x3C3C74F3, 0xD2D14B61, 0xBB04A2C1, 0xC5626167
    };

    private static uint Rotate(uint x, int count) { return (x >> count) | (x << (32 - count)); }
    private static uint Swap(uint x) { return Rotate(x, 16); }
    private static uint Sigma0(uint x) { return Rotate(x, 7) ^ Rotate(x, 18) ^ (x >> 3); }
    private static uint Sigma1(uint x) { return Rotate(x, 17) ^ Rotate(x, 19) ^ (x >> 10); }
    private static uint ReadBig(byte[] bytes, int offset, int count)
    {
        uint word = 0;
        for (int i = 0; i < count; i++) word = (word << 8) | bytes[offset + i];
        return word;
    }
    private static uint ReadLittle(byte[] bytes, int offset)
    {
        uint word = 0;
        for (int i = 0; i < 4 && offset + i < bytes.Length; i++) word |= (uint)bytes[offset + i] << (8 * i);
        return word;
    }
    private static void Expand(uint[] words, int start)
    {
        unchecked {
            for (int i = start; i < 64; i++)
                words[i] = Sigma1(words[i - 2]) + words[i - 7] + Sigma0(words[i - 15]) + words[i - 16];
        }
    }
    private static void Compress(uint[] state, uint[] words, uint[] working, int start)
    {
        unchecked {
            uint a = working[0], b = working[1], c = working[2], d = working[3];
            uint e = working[4], f = working[5], g = working[6], h = working[7];
            for (int i = start; i < 64; i++) {
                uint k = start == 14 && i == 14 ? 0xC9DC06A7 : Constants[i];
                uint t1 = h + (Rotate(e, 6) ^ Rotate(e, 11) ^ Rotate(e, 25)) + (g ^ (e & (f ^ g))) + k + words[i];
                uint t2 = (Rotate(a, 2) ^ Rotate(a, 13) ^ Rotate(a, 22)) + ((a & b) | (c & (a | b)));
                h = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2;
            }
            uint[] result = { a, b, c, d, e, f, g, h };
            for (int i = 0; i < 8; i++) state[i] += result[i];
        }
    }
    private static byte[] Digest(byte[] data)
    {
        unchecked {
            uint[] words = new uint[64];
            words[14] = ReadBig(data, 0, 3);
            words[15] = ReadBig(data, 3, 4);
            for (int i = 16; i < 30; i++) {
                uint word = ScheduleSeed[i - 16];
                if (i - 2 >= 14) word += Sigma1(words[i - 2]) ^ (i == 16 ? 0x000B92C0u : 0u);
                if (i - 7 >= 14) word += words[i - 7];
                if (i - 15 >= 14) word += Sigma0(words[i - 15]) ^ (i == 29 ? 0x059C0B80u : 0u);
                words[i] = word;
            }
            words[30] = Sigma1(words[28]) + words[23] + Sigma0(words[15]) + words[14] + 0xC9DC06A7 - Constants[14];
            Expand(words, 31);
            uint[] state = (uint[])Initial.Clone();
            uint[] working = { 0xFD9FBEA2, 0x91243CE7, 0xBE499094, 0xCD2E1E0A, 0x6C006F49, 0x04BD35AB, 0xFEB0A7E4, 0x03EFFBD2 };
            Compress(state, words, working, 14);

            // The protocol has already consumed 57 bytes before this salt.
            int length = 57 + data.Length;
            int zeroCount = (55 - length % 64 + 64) % 64;
            byte[] padded = new byte[data.Length - 7 + 1 + zeroCount + 8];
            System.Buffer.BlockCopy(data, 7, padded, 0, data.Length - 7);
            padded[data.Length - 7] = 0x80;
            ulong bits = (ulong)length * 8;
            for (int i = 0; i < 8; i++) padded[padded.Length - 1 - i] = (byte)(bits >> (i * 8));
            for (int offset = 0; offset < padded.Length; offset += 64) {
                for (int i = 0; i < 16; i++) words[i] = ReadBig(padded, offset + i * 4, 4);
                Expand(words, 16);
                Compress(state, words, (uint[])state.Clone(), 0);
            }
            byte[] digest = new byte[32];
            for (int i = 0; i < digest.Length; i++) digest[i] = (byte)(state[i / 4] >> (24 - 8 * (i % 4)));
            return digest;
        }
    }
    public static string Generate(long unixSeconds, string trustedToken)
    {
        unchecked {
            long seconds = unixSeconds + 11644473600L;
            long ticks = (seconds - seconds % 300) * 10000000L;
            byte[] data = System.Text.Encoding.ASCII.GetBytes(ticks.ToString(System.Globalization.CultureInfo.InvariantCulture) + trustedToken);
            byte[] digest = Digest(data);
            uint keyA = ReadLittle(digest, 0) | 1, keyB = ReadLittle(digest, 4) | 1;
            uint[] factors = { keyA * 0x82893933, keyB * 0x82893933 };
            byte[] input = new byte[data.Length + 1];
            System.Buffer.BlockCopy(data, 0, input, 1, data.Length);
            int wordCount = ((input.Length + 7) / 8) * 2;
            uint swapAcc = 0, swapLast = 0, state = 0, acc = 0;
            for (int i = 0; i < CsCoefficients.Length + wordCount; i += 2) {
                uint[] terms = new uint[2], offsets = new uint[2];
                for (int j = 0; j < 2; j++) {
                    int index = i + j;
                    if (index < CsCoefficients.Length) {
                        terms[j] = CsCoefficients[index] * factors[j];
                        offsets[j] = CsOffsets[index];
                    } else {
                        int position = index - CsCoefficients.Length;
                        uint word = ReadLittle(input, position * 4);
                        terms[j] = word * (j == 0 ? keyA : keyB);
                        offsets[j] = Swap(word) * (j == 0 ? 0xEF0569FBu : 0xC31713DBu);
                        if (position == 0) { terms[j] += 0xF2F90B1A * factors[0]; offsets[j] += 0x0B1A0000; }
                    }
                }
                uint q0 = Swap(offsets[0] + terms[0]) * 0x76F50F34;
                uint q1 = Swap(offsets[1] + terms[1]) * 0x1881CE3C;
                swapLast = Swap(q1) * 0x35BD1EC9 + q1;
                swapAcc += Swap(q0) * 0xC3EFEA97 + q0 + swapLast;
                state = Swap(state * keyA + terms[0]) * 0xCF98B111;
                state = Swap(state) * 0x87085B9F;
                state = Swap(state) * 0x12CEB96D;
                state = Swap(state) * 0x257E1D83;
                acc += state;
                state = Swap(state * keyB + terms[1]) * 0xA27416F5;
                state = Swap(state) * 0xD38396FF;
                state = Swap(Swap(state) * 0x7C932B89) * 0xBFA49F69;
                acc += state;
            }
            byte[] cs64 = new byte[8];
            uint left = swapLast ^ state, right = swapAcc ^ acc;
            for (int i = 0; i < 4; i++) { cs64[i] = (byte)(left >> (8 * i)); cs64[i + 4] = (byte)(right >> (8 * i)); }
            return System.BitConverter.ToString(cs64).Replace("-", "") + "-" + System.BitConverter.ToString(digest).Replace("-", "");
        }
    }
}
)'
}
