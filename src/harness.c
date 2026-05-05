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
        png_destroy_read_struct(&png, &info, NULL);
        fclose(fp);
        return 0;
    }

    png_init_io(png, fp);

    png_read_info(png, info);

    png_set_expand(png);
    png_read_update_info(png, info);

    // attempt to read the image rows
    int height = png_get_image_height(png, info);
    int rowbytes = png_get_rowbytes(png, info);
    if ((size_t)height * rowbytes < 10 * 1024 * 1024) {
        png_bytep row_ptr = malloc(rowbytes);
        if (row_ptr) {
            for (int i = 0; i < height; i++) {
                png_read_row(png, row_ptr, NULL);
            }
            free(row_ptr);
        }
    }

    png_read_end(png, NULL);

    // Cleanup
    png_destroy_read_struct(&png, &info, NULL);
    fclose(fp);

    return 0;
}