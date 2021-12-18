#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
    for (int i = 0; i < 25; i++)
        sleep(5);
    return 0;
}
