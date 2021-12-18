#include <assert.h>
#include <stdio.h>
#include <pthread.h>

typedef struct {
    char tid;
    int a;
    int b;
} myarg_t;

void *mythread(void *arg) {
    myarg_t *args = (myarg_t *) arg;
    printf("mythread %c, args: %d %d\n", args->tid, args->a, args->b);
    printf("mythread %c done\n", args->tid);
    return NULL;
}

int main(int argc, char *argv[]) {
    pthread_t p1, p2, p3;
    myarg_t args1 = { 'A', 10, 20 };
    myarg_t args2 = { 'B', 10, 20 };
    myarg_t args3 = { 'C', 10, 20 };

    int rc = pthread_create(&p1, NULL, mythread, &args1);
    assert(rc == 0);
    rc = pthread_create(&p2, NULL, mythread, &args2);
    assert(rc == 0);
    rc = pthread_create(&p3, NULL, mythread, &args3);
    assert(rc == 0);
    (void) pthread_join(p1, NULL);
    (void) pthread_join(p2, NULL);
    (void) pthread_join(p3, NULL);
    printf("main done\n");
    return 0;
}
