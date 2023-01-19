#include <getopt.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define FN_LEN 256
struct Options {
    bool using_h; // -h, human readable
    bool using_f; // -f, has a file optarg
    char filename[FN_LEN]; // -f optarg
};

static void init_opts(struct Options* opts) {
    opts->using_h = false;
    opts->using_f = false;
    for (int i = 0; i < FN_LEN; i++)
        opts->filename[i] = 0;
}

struct Options opts;

struct Options get_opts(int count, char* args[]) {
    init_opts(&opts);
    int opt;

    while ((opt = getopt(count, args, ":f:had")) != -1) {
        switch (opt) {
            case 'h': opts.using_h = true;
                printf("Hello World!\n");
                break;
            case 'f':
                opts.using_f = true;
                strcpy(opts.filename, optarg);
                // need to ensure that the argument following -f is a file
                // currently allowing pid to be read in as the filename
                printf("Printing file %s\n", opts.filename);
                // print out contents of file
                FILE *fp;
                char c;
                fp = fopen(opts.filename, "r");
                if (fp == NULL) {
                    printf("Could not open file %s", opts.filename);
                    exit(-1);
                }
                for (c = getc(fp); c != EOF; c = getc(fp))
                    putchar(c);
                fclose(fp);
                break;
            case ':':
                printf("-f needs a value\n");
                break;
            case '?':
                printf("Unknown option\n");
                exit(-1);
        }
    }
    return opts;
}

int main(int argc, char *argv[]) {
    //check if the final argument is an integer, if not, exit
    int pid = atoi(argv[argc - 1]);
    if (pid == 0) {
        printf("Error - last argument must be a pid\n");
        exit(-1);
    }

    struct Options o = get_opts(argc, argv);
    printf("my_kill pid: %d\n", getpid()); // get my_kill’s pid
    return 0;
}