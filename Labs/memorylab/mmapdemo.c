#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <stdlib.h>
#include <string.h>

/*
See 
https://www.clear.rice.edu/comp321/html/laboratories/lab10/
https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemAdvancedPT/MappingFilesIntoMemory/MappingFilesIntoMemory.html

This program uses the mmap system call to map the contents of itself into memory.
The entire contents of this file is mapped into memory. Like reading the entire file into memory.
After mapping itself to memory, the program iterates through the char's and prints them

This program uses mmap to allocate memory. This is similar to calling malloc; however, mmap is a system call and malloc is a C runtime call that manages memory. malloc requests a large block of memory from the OS using a system call such as mmap, and then manages malloc/free.

Observations - 
The two calls to mmap returned the same address. The first address was unmapped, which allowed the os to reuse the same address. The second call to mmap returned a buffer that was zero filled.

The addresses returned from mmap are in the range of addresses on the heap.

 */
static int g = 5;
int main(void) {
    struct stat stat;
    int fd, size;
    char *buf;

    // Open the file and get its size.
    fd = open("mmapdemo.c", O_RDONLY);
    if (fd < 0 || fstat(fd, &stat) < 0) {
        fprintf(stderr, "open() or fstat() failed.\n");
        return (1);
    }
    size = stat.st_size;

    printf("%d\n", size);

    // Map the file to a new virtual memory area.
    buf = mmap(NULL, size, PROT_READ, MAP_PRIVATE, fd, 0);
    if (buf == MAP_FAILED) {
        fprintf(stderr, "mmap(1) failed.\n");
        return (1);
    }
    char *p = malloc(4);
    printf("static: %p, heap: %p, stack: %p, mmap: %p\n", &g, p, &stat, buf);
    printf("%d", buf[0]);

    // Print out the contents of the file to stdout.
    for (int i = 0; i < size; i++) {
        printf("%c", buf[i]);
    }

    // Clean up.  Ignore the return values because we exit anyway.
    (void)munmap(buf, size);
    (void)close(fd);


    // Allocate 32 bytes of memory using mmap
    buf = mmap(0, 32, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0);
    if (buf == MAP_FAILED) {
        fprintf(stderr, "mmap(2) failed.\n");
        return (1);
    }
    printf("%d\n", buf[0]);
    printf("static: %p, heap: %p, stack: %p, mmap: %p\n", &g, p, &stat, buf);
    strcpy(buf, "Gusty");
    printf("%s\n", buf);
    munmap(buf, 32);


    return (0);
}
