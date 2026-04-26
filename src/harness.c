#include <stdio.h>
#include <stdlib.h>
#include <png.h>

int main(int argc, char *argv[]) {
    if (argc < 2) {
        return 1;
    }

    FILE *fp = fopen(argv[1], "rb");
    if (!fp) {
        return 1;
    }

    // Read PNG signature
    unsigned char header[8];
    fread(header, 1, 8, fp);

    if (png_sig_cmp(header, 0, 8)) {
        fclose(fp);
        return 0; // not a PNG, ignore
    }

    // Create PNG read struct
    png_structp png = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    if (!png) {
        fclose(fp);
        return 1;
    }

    png_infop info = png_create_info_struct(png);
    if (!info) {
        png_destroy_read_struct(&png, NULL, NULL);
        fclose(fp);
        return 1;
    }

    if (setjmp(png_jmpbuf(png))) {
        // libpng error handling
        png_destroy_read_struct(&png, &info, NULL);
        fclose(fp);
        return 0;
    }

    png_init_io(png, fp);
    png_set_sig_bytes(png, 8);

    png_read_info(png, info);

    // Cleanup
    png_destroy_read_struct(&png, &info, NULL);
    fclose(fp);

    return 0;
}