#include <stdio.h>

#include "mythreads.h"

int balance = 0;
int loops = 0;

void* worker(void* arg) {
    for (int i = 0; i < loops; i++)
        balance++; // unprotected access 
    return NULL;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("$ main-race num_loops\n");
        exit(-1);
    }
    loops = atoi(argv[1]);
    pthread_t p;
    Pthread_create(&p, NULL, worker, NULL);
    for (int i = 0; i < loops; i++)
        balance++; // unprotected access
    Pthread_join(p, NULL);
    printf("%d\n", balance);
    return 0;
}
