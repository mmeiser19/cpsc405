#include <pthread.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <sys/wait.h>
//#define MAX 10

int main(int argc, char *argv[]) {
    //only accepts first argument
    char* input = argv[1];
    //get the size of the input
    int size = strlen(input);
    printf("%s %d\n", input, size);
    char inbuf[size];
    char inbuf2[size];
    //int turn = 0;

    //make pipe2
    int fd[2];
    pipe(fd);

    //make pipe1
    int p[2];
    pipe(p);

    pid_t pid = fork(); // this will go to the child first, then the parent

    if(pid > 0) {
        //actions before wait
        printf("Parent Write: %s\n", input);
        dup(p[1]);
        write(p[1], input, size);
        //turn++;

        //allows child to finish
        wait(NULL);

        // duplicating fd[0] with standard input 0
        dup(fd[0]);

        // n stores the total bytes read successfully
        int n = read(fd[0], inbuf, size);
        inbuf[n] = '\0'; //adds null terminator to end of inbuff since it was lacking one
        printf("Parent Read: %s %d\n ", inbuf, n);
    }
    else if( pid == 0 ) {
        //forces child to wait until parent waits
        wait(NULL);

        //read from pipe1
        dup(p[0]);
        int n2 = read(p[0], inbuf2, size);
        printf("Child Read: %s %d\n", inbuf2, n2);

        // no need to use the read end of pipe here so close it
        //close(fd[0]);

        // duplicating fd[0] with standard output 1
        printf("Child Write: %s\n", inbuf2);
        dup(fd[1]);
        //printf("Child Write\n");
        write(fd[1], inbuf2, size);
        //close(fd[1]);

    }

    else {
        perror("error\n"); //fork()
    }
}