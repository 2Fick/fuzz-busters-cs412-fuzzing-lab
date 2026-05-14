#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <png.h>

/*
 * In-memory read callback for libpng: reads from a buffer instead of a file.
 * Persistent mode delivers input via a shared memory buffer, not a file on
 * disk, so we cannot use png_init_io(). This callback lets libpng pull bytes
 * directly from the AFL++ testcase buffer.
 */
typedef struct {
    const unsigned char *data;
    size_t size;
    size_t pos;
} mem_reader_t;

static void mem_read(png_structp png, png_bytep out, png_size_t count) {
    mem_reader_t *r = (mem_reader_t *)png_get_io_ptr(png);
    if (r->pos + count > r->size) {
        png_error(png, "read past end of buffer");
        return;
    }
    memcpy(out, r->data + r->pos, count);
    r->pos += count;
}

__AFL_FUZZ_INIT();

int main(void) {
    __AFL_INIT();

    unsigned char *buf = __AFL_FUZZ_TESTCASE_BUF;

    while (__AFL_LOOP(10000)) {
        int len = __AFL_FUZZ_TESTCASE_LEN;
        if (len < 8) continue;

        mem_reader_t reader = { buf, (size_t)len, 0 };

        png_structp png = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
        if (!png) continue;

        png_infop info = png_create_info_struct(png);
        if (!info) {
            png_destroy_read_struct(&png, NULL, NULL);
            continue;
        }

        if (setjmp(png_jmpbuf(png))) {
            png_destroy_read_struct(&png, &info, NULL);
            continue;
        }

        png_set_read_fn(png, &reader, mem_read);
        png_read_info(png, info);
        png_set_expand(png);
        png_read_update_info(png, info);

        int height   = png_get_image_height(png, info);
        int rowbytes = png_get_rowbytes(png, info);

        if ((size_t)height * rowbytes < 10 * 1024 * 1024) {
            png_bytep row_ptr = malloc(rowbytes);
            if (row_ptr) {
                for (int i = 0; i < height; i++)
                    png_read_row(png, row_ptr, NULL);
                free(row_ptr);
            }
        }

        png_read_end(png, NULL);
        png_destroy_read_struct(&png, &info, NULL);
    }

    return 0;
}
