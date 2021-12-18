#include <stdio.h>

#include "mythreads.h"

pthread_mutex_t m1 = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t m2 = PTHREAD_MUTEX_INITIALIZER;

void* worker(void* arg) {
    if ((long) arg == 0) {
	Pthread_mutex_lock(&m1);
        printf("worker%ld has mutex m1, waiting on m2.\n", (long)arg);
        sched_yield();
	Pthread_mutex_lock(&m2);
        printf("worker%ld has mutex m2.\n", (long)arg);
    } else {
	Pthread_mutex_lock(&m2);
        printf("worker%ld has mutex m2, waiting on m1.\n", (long)arg);
        sched_yield();
	Pthread_mutex_lock(&m1);
        printf("worker%ld has mutex m1.\n", (long)arg);
    }
    Pthread_mutex_unlock(&m1);
    Pthread_mutex_unlock(&m2);
    return NULL;
}

int main(int argc, char *argv[]) {
    pthread_t p1, p2;
    Pthread_create(&p1, NULL, worker, (void *) (long) 0);
    Pthread_create(&p2, NULL, worker, (void *) (long) 1);
    Pthread_join(p1, NULL);
    Pthread_join(p2, NULL);
    printf("All done!\n");
    return 0;
}
