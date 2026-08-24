/* Test-fixture generator: writes a video-only Ogg Theora file.
   Three colour segments with a marker that moves left-to-right, so the transcode
   can be checked frame-accurately against the source. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ogg/ogg.h>
#include <theora/theoraenc.h>

#define W 640
#define H 480
#define FPS 15
#define SECONDS 9

static unsigned char Yp[W*H], Cb[(W/2)*(H/2)], Cr[(W/2)*(H/2)];

static void fill_frame(int n) {
    int total = FPS * SECONDS;
    int seg = n / (FPS * 3);
    if (seg > 2) seg = 2;
    /* Distinct luma per segment so the segment is identifiable from Y alone. */
    unsigned char y[3] = {80, 110, 140};
    unsigned char cb[3] = {140, 100, 110};
    unsigned char cr[3] = {110, 150, 100};

    memset(Yp, y[seg], sizeof Yp);
    memset(Cb, cb[seg], sizeof Cb);
    memset(Cr, cr[seg], sizeof Cr);

    /* White marker sliding across the top, and fixed corner blocks. */
    int x = (int)((long)(W - 40) * n / (total > 1 ? total - 1 : 1));
    for (int r = 0; r < 40; r++)
        for (int c = 0; c < 40; c++)
            Yp[r * W + x + c] = 235;
    for (int r = 0; r < 24; r++) {
        for (int c = 0; c < 24; c++) {
            Yp[(H - 1 - r) * W + c] = 235;
            Yp[(H - 1 - r) * W + (W - 1 - c)] = 235;
        }
    }
}

static void write_page(FILE *f, ogg_page *p) {
    fwrite(p->header, 1, p->header_len, f);
    fwrite(p->body, 1, p->body_len, f);
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: mkogv out.ogv\n"); return 1; }
    FILE *out = fopen(argv[1], "wb");
    if (!out) { perror("fopen"); return 1; }

    th_info info;
    th_info_init(&info);
    info.frame_width = W; info.frame_height = H;
    info.pic_width = W;   info.pic_height = H;
    info.pic_x = 0;       info.pic_y = 0;
    info.colorspace = TH_CS_ITU_REC_470M;
    info.pixel_fmt = TH_PF_420;
    info.target_bitrate = 0;
    info.quality = 48;
    info.fps_numerator = FPS; info.fps_denominator = 1;
    info.aspect_numerator = 1; info.aspect_denominator = 1;

    th_enc_ctx *enc = th_encode_alloc(&info);
    if (!enc) { fprintf(stderr, "th_encode_alloc failed\n"); return 1; }

    ogg_stream_state os;
    ogg_stream_init(&os, 0x5eed);

    th_comment comment;
    th_comment_init(&comment);

    ogg_packet pkt;
    while (th_encode_flushheader(enc, &comment, &pkt) > 0)
        ogg_stream_packetin(&os, &pkt);

    ogg_page page;
    while (ogg_stream_flush(&os, &page) > 0) write_page(out, &page);

    int total = FPS * SECONDS;
    for (int n = 0; n < total; n++) {
        fill_frame(n);
        th_ycbcr_buffer buf;
        buf[0].width = W; buf[0].height = H; buf[0].stride = W; buf[0].data = Yp;
        buf[1].width = W/2; buf[1].height = H/2; buf[1].stride = W/2; buf[1].data = Cb;
        buf[2].width = W/2; buf[2].height = H/2; buf[2].stride = W/2; buf[2].data = Cr;

        if (th_encode_ycbcr_in(enc, buf) != 0) { fprintf(stderr, "encode in failed\n"); return 1; }
        int last = (n == total - 1);
        while (th_encode_packetout(enc, last, &pkt) > 0) {
            ogg_stream_packetin(&os, &pkt);
            while (ogg_stream_pageout(&os, &page) > 0) write_page(out, &page);
        }
    }
    while (ogg_stream_flush(&os, &page) > 0) write_page(out, &page);

    th_encode_free(enc);
    th_comment_clear(&comment);
    ogg_stream_clear(&os);
    th_info_clear(&info);
    fclose(out);
    fprintf(stderr, "wrote %d frames\n", total);
    return 0;
}
