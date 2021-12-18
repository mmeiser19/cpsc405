
FLAGS = -Wall -pthread

all: main-race main-deadlock main-deadlock-global main-signal main-signal-cv thread_create thread_create_simple_args thread_create_with_return_args

clean:
	rm -f main-race main-deadlock main-deadlock-global main-signal main-signal-cv thread_create thread_create_simple_args thread_create_with_return_args

main-race: main-race.c mythreads.h
	gcc -o main-race main-race.c $(FLAGS)

main-deadlock: main-deadlock.c mythreads.h
	gcc -o main-deadlock main-deadlock.c $(FLAGS)

main-deadlock-global: main-deadlock-global.c mythreads.h
	gcc -o main-deadlock-global main-deadlock-global.c $(FLAGS)

main-signal: main-signal.c mythreads.h
	gcc -o main-signal main-signal.c $(FLAGS)

main-signal-cv: main-signal-cv.c mythreads.h
	gcc -o main-signal-cv main-signal-cv.c $(FLAGS)

thread_create: thread_create.c
	gcc -o thread_create thread_create.c $(FLAGS)

thread_create_simple_args: thread_create_simple_args.c common_threads.h
	gcc -o thread_create_simple_args thread_create_simple_args.c $(FLAGS)

thread_create_with_return_args: thread_create_with_return_args.c common_threads.h
	gcc -o thread_create_with_return_args thread_create_with_return_args.c $(FLAGS)

