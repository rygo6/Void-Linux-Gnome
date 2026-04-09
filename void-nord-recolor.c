/* ==========================================================================
 * Void Nord Recolor
 * ==========================================================================
 * Recolors any PNG, SVG, or CSS file to match the Void Nord color scheme.
 *
 * Usage:
 *   void-nord-recolor <file.png|file.svg|file.css> [file2 ...]
 *
 * PNG files are recolored via per-pixel hue shifting (requires libpng).
 * SVG/CSS files are recolored via case-insensitive hex replacements.
 *
 * Build:
 *   cc -O2 -o void-nord-recolor void-nord-recolor.c -lpng -lm
 * ==========================================================================
 */

#include <ctype.h>
#include <math.h>
#include <png.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ---- Text color replacement table --------------------------------------- */

typedef struct {
    const char *from; /* lowercase */
    const char *to;
} HexReplace;

static const HexReplace hex_replacements[] = {
    /* Greens — targets are the four Void brand greens + derived intermediates */
    {"#35a854", "#478061"}, {"#88c663", "#abc2ab"}, {"#6db442", "#478061"},
    {"#568f34", "#406551"}, {"#98deab", "#abc2ab"}, {"#92b372", "#478061"},
    {"#9ad4aa", "#abc2ab"}, {"#a4d8b2", "#abc2ab"}, {"#73d216", "#478061"},
    {"#30974c", "#355c49"}, {"#30984c", "#355c49"}, {"#298141", "#295340"},
    {"#3bbb5e", "#406551"}, {"#2f954a", "#355c49"}, {"#5acb78", "#478061"},
    {"#236e37", "#295340"}, {"#71d28b", "#79a186"}, {"#3ab85c", "#406551"},
    {"#4ac66b", "#478061"},
    /* Light greens (CSS hover/focus tints) */
    {"#e1f2e5", "#d5e1d5"}, {"#d7eedd", "#c8d8c8"}, {"#ebf6ee", "#dde8dd"},
    {"#c2e5cc", "#b0c8b0"}, {"#aedcbb", "#a0baa0"}, {"#86cb98", "#79a186"},
    /* Reds / oranges */
    {"#ef2929", "#bf616a"}, {"#f57900", "#d08770"}, {"#f70505", "#bf616a"},
    {"#f75a61", "#cf717a"}, {"#d8354a", "#af515a"}, {"#ff7a80", "#df818a"},
    /* Arc-dark background blues (SVG widget backgrounds) → neutral libadwaita darks */
    {"#383c4a", "#2e2e32"}, {"#353945", "#2e2e32"}, {"#2b2f3b", "#28282c"},
    {"#252a35", "#222226"}, {"#3c4049", "#36363a"}, {"#161a26", "#1d1d20"},
    {"#0f1116", "#1d1d20"}, {"#1b1c21", "#1d1d20"},
    /* Mint-Y blueish darks → libadwaita defaults */
    {"#303036", "#2e2e32"}, {"#3c3c44", "#36363a"}, {"#44444c", "#36363a"},
    {"#38383e", "#36363a"}, {"#494951", "#505053"}, {"#29292e", "#28282c"},
    {"#5e5e69", "#505053"}, {"#333339", "#2e2e32"}, {"#202023", "#1d1d20"},
    {"#2c2c31", "#28282c"}, {"#18181b", "#1d1d20"}, {"#313136", "#2e2e32"},
    {"#161619", "#1d1d20"}, {"#1b1b1e", "#1d1d20"}, {"#1d1d21", "#1d1d20"},
    {"#242429", "#222226"}, {"#26262a", "#252529"}, {"#27272b", "#28282c"},
    {"#27272c", "#28282c"}, {"#2a2a2f", "#28282c"}, {"#313137", "#2e2e32"},
    {"#39393f", "#36363a"}, {"#3a3a41", "#36363a"}, {"#46464e", "#36363a"},
    {"#4c4c50", "#505053"}, {"#555559", "#505053"}, {"#55555f", "#505053"},
    {"#333338", "#2e2e32"},
    {"#111113", "#1d1d20"}, {"#141416", "#1d1d20"}, {"#616166", "#505053"},
    {"#5c616c", "#505053"},
    {"#424246", "#36363a"},
    /* Mint-Y specific darks → closest libadwaita match */
    {"#2e2e33", "#2e2e32"}, /* Mint-Y window bg → libadwaita headerbar */
    {"#2a2a2e", "#28282c"}, /* Mint-Y sidebar → libadwaita sidebar_backdrop */
    /* Neutral grays → libadwaita +4 blue tint equivalents */
    {"#1c1c1c", "#1c1c20"}, {"#212121", "#212125"},
    {"#2b2b2b", "#2b2b2f"}, {"#303030", "#303034"},
    {"#353535", "#353539"}, {"#373737", "#37373b"},
    {"#393939", "#39393d"}, {"#3f3f3f", "#3f3f43"},
    {"#414141", "#414145"}, {"#474747", "#47474b"},
    {"#4a4a4a", "#4a4a4e"}, {"#5c5c5c", "#5c5c60"},
    {NULL, NULL}
};

typedef struct {
    const char *from;
    const char *to;
} RgbaReplace;

static const RgbaReplace rgba_replacements[] = {
    {"rgba(53, 168, 84",   "rgba(71, 128, 97"},     /* #35a854 → #478061 */
    {"rgba(109, 180, 66",  "rgba(71, 128, 97"},     /* #6db442 → #478061 */
    {"rgba(136, 198, 99",  "rgba(171, 194, 171"},   /* #88c663 → #abc2ab */
    {"rgba(141, 206, 158", "rgba(171, 194, 171"},   /* lighter green → #abc2ab */
    {"rgba(41, 129, 65",   "rgba(41, 83, 64"},      /* darker green → #295340 */
    {"rgba(50, 160, 80",   "rgba(64, 101, 81"},     /* medium green → #406551 */
    {"rgba(0, 255, 0",     "rgba(71, 128, 97"},     /* pure green → #478061 */
    {"rgba(252, 65, 56",   "rgba(191, 97, 106"},
    {"rgba(245, 121, 0",   "rgba(208, 135, 112"},
    /* Mint-Y blueish rgba darks → libadwaita defaults */
    {"rgba(48, 48, 54",    "rgba(46, 46, 50"},   /* → headerbar #2e2e32 */
    {"rgba(29, 29, 33",    "rgba(29, 29, 32"},   /* → view_bg #1d1d20 */
    {"rgba(46, 46, 51",    "rgba(46, 46, 50"},   /* → headerbar */
    {"rgba(27, 27, 30",    "rgba(28, 28, 32"},   /* → sidebar_backdrop */
    {"rgba(32, 32, 35",    "rgba(34, 34, 38"},   /* → window_bg area */
    {"rgba(42, 42, 47",    "rgba(40, 40, 44"},   /* → sidebar_backdrop */
    {"rgba(51, 51, 57",    "rgba(54, 54, 58"},   /* → dialog_bg */
    {"rgba(56, 56, 62",    "rgba(54, 54, 58"},   /* → dialog_bg */
    {"rgba(60, 60, 68",    "rgba(54, 54, 58"},   /* → dialog_bg */
    {"rgba(67, 67, 73",    "rgba(54, 54, 58"},   /* → dialog_bg */
    {"rgba(87, 87, 97",    "rgba(80, 80, 83"},   /* → toast_bg */
    {"rgba(98, 98, 102",   "rgba(80, 80, 83"},   /* → toast_bg */
    {"rgba(46, 46, 50",    "rgba(46, 46, 50"},   /* already libadwaita */
    {"rgba(66, 66, 70",    "rgba(54, 54, 58"},   /* → dialog_bg */
    {NULL, NULL}
};

/* ---- PNG hue-shift table ------------------------------------------------ */

typedef struct {
    float h_min, h_max;    /* degrees */
    float target_h;        /* 0..1 */
    float sat_mult;
    float val_mult;
} HueMap;

static const HueMap hue_map[] = {
    {  0,  30, 355.f/360, 0.45f, 0.80f},
    {330, 360, 355.f/360, 0.45f, 0.80f},
    { 30,  50,  22.f/360, 0.50f, 0.82f},
    { 50,  80,  43.f/360, 0.50f, 0.85f},
    { 80, 180, 150.f/360, 0.40f, 0.65f},
    {180, 260, 160.f/360, 0.35f, 0.72f},
    {260, 330, 310.f/360, 0.35f, 0.75f},
};
#define HUE_MAP_LEN (sizeof(hue_map) / sizeof(hue_map[0]))

/* ---- color conversion --------------------------------------------------- */

static void rgb_to_hsv(float r, float g, float b,
                       float *h, float *s, float *v)
{
    float mx = r > g ? (r > b ? r : b) : (g > b ? g : b);
    float mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
    float d  = mx - mn;

    *v = mx;
    *s = (mx > 0) ? d / mx : 0;

    if (d == 0) {
        *h = 0;
    } else if (mx == r) {
        *h = fmodf((g - b) / d, 6.f) / 6.f;
        if (*h < 0) *h += 1.f;
    } else if (mx == g) {
        *h = ((b - r) / d + 2.f) / 6.f;
    } else {
        *h = ((r - g) / d + 4.f) / 6.f;
    }
}

static void hsv_to_rgb(float h, float s, float v,
                       float *r, float *g, float *b)
{
    float c = v * s;
    float x = c * (1.f - fabsf(fmodf(h * 6.f, 2.f) - 1.f));
    float m = v - c;
    int   i = (int)(h * 6.f) % 6;

    switch (i) {
    case 0: *r = c; *g = x; *b = 0; break;
    case 1: *r = x; *g = c; *b = 0; break;
    case 2: *r = 0; *g = c; *b = x; break;
    case 3: *r = 0; *g = x; *b = c; break;
    case 4: *r = x; *g = 0; *b = c; break;
    default:*r = c; *g = 0; *b = x; break;
    }
    *r += m; *g += m; *b += m;
}

/* ---- SVG recolor -------------------------------------------------------- */

/* Case-insensitive memmem for short needles */
static const char *ci_find(const char *hay, size_t hlen,
                           const char *needle, size_t nlen)
{
    if (nlen == 0 || nlen > hlen) return NULL;
    size_t limit = hlen - nlen;
    for (size_t i = 0; i <= limit; i++) {
        size_t j;
        for (j = 0; j < nlen; j++) {
            if (tolower((unsigned char)hay[i + j]) !=
                tolower((unsigned char)needle[j]))
                break;
        }
        if (j == nlen) return hay + i;
    }
    return NULL;
}

/* Exact (non-case-insensitive) substring find */
static const char *exact_find(const char *hay, size_t hlen,
                              const char *needle, size_t nlen)
{
    if (nlen == 0 || nlen > hlen) return NULL;
    return memmem(hay, hlen, needle, nlen);
}

static int recolor_text(const char *path)
{
    printf("Recoloring: %s\n", path);

    FILE *f = fopen(path, "rb");
    if (!f) { perror(path); return 1; }
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    rewind(f);

    char *buf = malloc(sz + 1);
    if (!buf) { fclose(f); fprintf(stderr, "OOM\n"); return 1; }
    fread(buf, 1, sz, f);
    buf[sz] = '\0';
    fclose(f);

    /* Repeatedly scan and replace.  We build a new buffer each pass per
       replacement type, but given typical SVG sizes this is fine. */

    /* Hex replacements (case-insensitive) */
    for (const HexReplace *rp = hex_replacements; rp->from; rp++) {
        size_t flen = strlen(rp->from);
        size_t tlen = strlen(rp->to);
        /* scan */
        size_t buflen = strlen(buf);
        /* Count occurrences first */
        int cnt = 0;
        const char *p = buf;
        while ((p = ci_find(p, buflen - (p - buf), rp->from, flen)) != NULL) {
            cnt++;
            p += flen;
        }
        if (cnt == 0) continue;

        size_t newlen = buflen + cnt * ((long)tlen - (long)flen);
        char *out = malloc(newlen + 1);
        if (!out) { free(buf); fprintf(stderr, "OOM\n"); return 1; }

        char *wp = out;
        p = buf;
        const char *found;
        while ((found = ci_find(p, buflen - (p - buf), rp->from, flen))) {
            memcpy(wp, p, found - p);
            wp += found - p;
            memcpy(wp, rp->to, tlen);
            wp += tlen;
            p = found + flen;
        }
        size_t tail = buflen - (p - buf);
        memcpy(wp, p, tail);
        wp[tail] = '\0';
        free(buf);
        buf = out;
        buflen = newlen;
    }

    /* rgba() replacements (exact match) */
    for (const RgbaReplace *rp = rgba_replacements; rp->from; rp++) {
        size_t flen = strlen(rp->from);
        size_t tlen = strlen(rp->to);
        size_t buflen = strlen(buf);
        int cnt = 0;
        const char *p = buf;
        while ((p = exact_find(p, buflen - (p - buf), rp->from, flen))) {
            cnt++;
            p += flen;
        }
        if (cnt == 0) continue;

        size_t newlen = buflen + cnt * ((long)tlen - (long)flen);
        char *out = malloc(newlen + 1);
        if (!out) { free(buf); fprintf(stderr, "OOM\n"); return 1; }

        char *wp = out;
        p = buf;
        const char *found;
        while ((found = exact_find(p, buflen - (p - buf), rp->from, flen))) {
            memcpy(wp, p, found - p);
            wp += found - p;
            memcpy(wp, rp->to, tlen);
            wp += tlen;
            p = found + flen;
        }
        size_t tail = buflen - (p - buf);
        memcpy(wp, p, tail);
        wp[tail] = '\0';
        free(buf);
        buf = out;
    }

    f = fopen(path, "wb");
    if (!f) { perror(path); free(buf); return 1; }
    fwrite(buf, 1, strlen(buf), f);
    fclose(f);
    free(buf);
    printf("   Done.\n");
    return 0;
}

/* ---- PNG recolor -------------------------------------------------------- */

static int recolor_png(const char *path)
{
    printf("Recoloring PNG: %s\n", path);

    FILE *f = fopen(path, "rb");
    if (!f) { perror(path); return 1; }

    png_structp rp = png_create_read_struct(PNG_LIBPNG_VER_STRING,
                                            NULL, NULL, NULL);
    png_infop ri = png_create_info_struct(rp);
    if (setjmp(png_jmpbuf(rp))) {
        fprintf(stderr, "%s: PNG read error\n", path);
        png_destroy_read_struct(&rp, &ri, NULL);
        fclose(f);
        return 1;
    }

    png_init_io(rp, f);
    png_read_png(rp, ri,
                 PNG_TRANSFORM_EXPAND | PNG_TRANSFORM_STRIP_16 |
                 PNG_TRANSFORM_GRAY_TO_RGB, NULL);

    png_uint_32 w = png_get_image_width(rp, ri);
    png_uint_32 h = png_get_image_height(rp, ri);
    int channels  = png_get_channels(rp, ri);
    png_bytepp rows = png_get_rows(rp, ri);

    /* After transforms we should have 3 (RGB) or 4 (RGBA) channels */
    if (channels < 3) {
        printf("   Skipped (unsupported channel count: %d)\n", channels);
        png_destroy_read_struct(&rp, &ri, NULL);
        fclose(f);
        return 0;
    }

    int has_alpha = (channels == 4);
    int modified  = 0;

    for (png_uint_32 y = 0; y < h; y++) {
        png_bytep row = rows[y];
        for (png_uint_32 x = 0; x < w; x++) {
            png_bytep px = row + x * channels;
            unsigned char r = px[0], g = px[1], b = px[2];
            unsigned char a = has_alpha ? px[3] : 255;

            if (a == 0) continue;

            float hue, sat, val;
            rgb_to_hsv(r / 255.f, g / 255.f, b / 255.f, &hue, &sat, &val);

            if (sat < 0.15f) {
                /* Normalize blue-tinted dark backgrounds to libadwaita's
                   consistent +4 blue offset (R=G, B=R+4). */
                if (b > r && b > g && (b - (r < g ? r : g)) > 1) {
                    unsigned char avg = (r + g) / 2;
                    unsigned char nb  = avg + 4 < 255 ? avg + 4 : 255;
                    if (px[0] != avg || px[1] != avg || px[2] != nb) {
                        px[0] = avg;
                        px[1] = avg;
                        px[2] = nb;
                        modified = 1;
                    }
                }
                continue;
            }

            float hue_deg = hue * 360.f;
            for (size_t i = 0; i < HUE_MAP_LEN; i++) {
                if (hue_deg > hue_map[i].h_min &&
                    hue_deg < hue_map[i].h_max) {
                    float ns = sat * hue_map[i].sat_mult;
                    float nv = val * hue_map[i].val_mult;
                    if (ns > 1.f) ns = 1.f;
                    if (nv > 1.f) nv = 1.f;

                    float nr, ng, nb;
                    hsv_to_rgb(hue_map[i].target_h, ns, nv, &nr, &ng, &nb);
                    px[0] = (unsigned char)(nr * 255.f + 0.5f);
                    px[1] = (unsigned char)(ng * 255.f + 0.5f);
                    px[2] = (unsigned char)(nb * 255.f + 0.5f);
                    modified = 1;
                    break;
                }
            }
        }
    }

    fclose(f);

    if (!modified) {
        printf("   No saturated pixels found — file unchanged.\n");
        png_destroy_read_struct(&rp, &ri, NULL);
        return 0;
    }

    /* Write back */
    f = fopen(path, "wb");
    if (!f) { perror(path); png_destroy_read_struct(&rp, &ri, NULL); return 1; }

    png_structp wp = png_create_write_struct(PNG_LIBPNG_VER_STRING,
                                             NULL, NULL, NULL);
    png_infop wi = png_create_info_struct(wp);
    if (setjmp(png_jmpbuf(wp))) {
        fprintf(stderr, "%s: PNG write error\n", path);
        png_destroy_write_struct(&wp, &wi);
        png_destroy_read_struct(&rp, &ri, NULL);
        fclose(f);
        return 1;
    }

    png_init_io(wp, f);
    png_set_IHDR(wp, wi, w, h, 8,
                 has_alpha ? PNG_COLOR_TYPE_RGBA : PNG_COLOR_TYPE_RGB,
                 PNG_INTERLACE_NONE,
                 PNG_COMPRESSION_TYPE_DEFAULT,
                 PNG_FILTER_TYPE_DEFAULT);
    png_set_rows(wp, wi, rows);
    png_write_png(wp, wi, PNG_TRANSFORM_IDENTITY, NULL);

    png_destroy_write_struct(&wp, &wi);
    png_destroy_read_struct(&rp, &ri, NULL);
    fclose(f);
    printf("   Done.\n");
    return 0;
}

/* ---- main --------------------------------------------------------------- */

static int str_ends_with_ci(const char *s, const char *suffix)
{
    size_t sl = strlen(s), xl = strlen(suffix);
    if (xl > sl) return 0;
    for (size_t i = 0; i < xl; i++)
        if (tolower((unsigned char)s[sl - xl + i]) !=
            tolower((unsigned char)suffix[i]))
            return 0;
    return 1;
}

int main(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr,
                "Usage: %s <file.png|file.svg|file.css> [file2 ...]\n"
                "Recolors image/text files to the Void Nord color scheme.\n",
                argv[0]);
        return 1;
    }

    int ret = 0;
    for (int i = 1; i < argc; i++) {
        FILE *test = fopen(argv[i], "rb");
        if (!test) {
            fprintf(stderr, "File not found: %s\n", argv[i]);
            ret = 1;
            continue;
        }
        fclose(test);

        if (str_ends_with_ci(argv[i], ".svg") ||
            str_ends_with_ci(argv[i], ".css") ||
            str_ends_with_ci(argv[i], ".rc")  ||
            str_ends_with_ci(argv[i], "gtkrc")) {
            ret |= recolor_text(argv[i]);
        } else if (str_ends_with_ci(argv[i], ".png")) {
            ret |= recolor_png(argv[i]);
        } else {
            fprintf(stderr, "Unsupported format: %s\n", argv[i]);
        }
    }
    return ret;
}
