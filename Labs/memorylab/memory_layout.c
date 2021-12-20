#include <stdio.h>
#include <stdlib.h>

int global = 5;
const int constant = 5;
char *s = "CPSC 405\n";
int main(int argc, char *argv[]) {
    startofmain:
    printf("location of main       : %p\n", main);
    printf("location of startofmain: %p\n", &&startofmain);
    printf("size of code           : %lx\n",  &&endofmain-&&startofmain);
    printf("end of code            : %p\n", &&endofmain);
    printf("location of globals    : %p\n", &global);
    printf("location of constants  : %p\n", &constant);
    printf("location of strings    : %p\n", s);
    int stack = 3;
    printf("location of stack      : %p\n", &stack);
    int *heap = malloc(100e6);
    printf("location of heap       : %p\n", heap);
    // Attempt to wrtie to memory in front of globals
    //int *p = &global - 400;
    //*p = 5;
    // Attempt to modify a constant
    //int *p = &constant;
    //*p = 5;
    // Attempt to modify a string literal
    //s[5] = '3';
    endofmain:
    return 0;
}
