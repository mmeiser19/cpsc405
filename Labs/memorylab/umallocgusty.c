//#include <types.h>
//#include <stat.h>
//#include <user.h>
//#include <param.h>
#include <stdlib.h>
#include <stdio.h>

unsigned char mem[4096*16]; // 4096 units * sizeof(header)
void *memp = (void *)mem;

typedef struct header {
    struct header *ptr;
    int size;
} Header;

static Header base = { &base, 0 };
static Header *freep = &base;

void my_free(void *udp) { // udp points to user data, not Header
    Header *hp, *p;

    hp = (Header*)udp - 1; // hp points to Header of block with user data
  //for (p = freep; (hp <= p || hp >= p->ptr); p = p->ptr)
    for (p = freep; !(hp > p && hp < p->ptr); p = p->ptr)
        if (p >= p->ptr && (hp > p || hp < p->ptr))
            break;
    if (hp + hp->size == p->ptr) { // collapse freed block with next
        hp->size += p->ptr->size;
        hp->ptr = p->ptr->ptr;
    } else                                                     // add returned block to free list
        hp->ptr = p->ptr;
    if (p + p->size == hp ){                 // collapse freed block with front of circular list
        p->size += hp->size;
        p->ptr = hp->ptr;
    } else                                                     // add returned block to free list
        p->ptr = hp;
    freep = p;
}

static Header* morecore(int nu) {
    char *p;
    Header *hp;

    if(nu < 4096)
        nu = 4096;
    //freemem = sbrk(nunits * sizeof(Header)); // get block from OS - original call
    //p = malloc(nu * sizeof(Header)); // get block from OS - works for this example
    //p = calloc(nu, sizeof(Header)); // get block from OS - works for this example

    p = (char *)&mem[0];

    if (p == 0)
        return 0;
    hp = (Header*)p;
    hp->size = nu;
    my_free((void*)(hp + 1)); // add this big block to our free list
    return freep; 
}

void *my_malloc(int nbytes) {
    Header *p, *prevp;

    int nunits = (nbytes + sizeof(Header) - 1) / sizeof(Header) + 1;
    prevp = freep;
    for(p = prevp->ptr; ; prevp = p, p = p->ptr){
        if(p->size >= nunits){
            if(p->size == nunits)
                prevp->ptr = p->ptr; // remove from free list
            else {
                p->size -= nunits;   // too big so adjust size
                p += p->size;        // p points to block to return, at bottom of free block
                p->size = nunits;    // block has nunits - amount requested
            }
            freep = prevp;           // update freep - circular linked list, can be any Header block
            return (void *)(p + 1);   // return pointer to user data
        }
        if (p == freep)              // Executed on first call to malloc and when morecore needed
            if ((p = morecore(nunits)) == 0)
                return 0;
    }
}

int main() {
    printf("sizeof(Header): %lu\n", sizeof(Header));
    int *p0 = my_malloc(4);
    *p0 = 5;
    printf("p0: %p, *p0: %d, mem[%ld]\n", p0, *p0, (void *)p0-memp);
    my_free(p0);
    p0 = my_malloc(4);
    printf("p0: %p, *p0: %d, mem[%ld]\n", p0, *p0, (void *)p0-memp);
    *p0 = 111;
    printf("p0: %p, *p0: %d, mem[%ld]\n", p0, *p0, (void *)p0-memp);
    double *p1 = my_malloc(8);
    *p1 = 1.0;
    printf("p1: %p, *p1: %lf, *p1: %lx, mem[%ld]\n", p1, *p1, (long)*p1, (void *)p1-memp);
    int *p2 = my_malloc(64);
    printf("p2: %p, mem[%ld]\n", p2, (void *)p2-memp);
    //my_free(p0);
    my_free(p1); // frees 8 bytes 
    int *p4 = my_malloc(4);
    printf("p4: %p, *p4: %d, mem[%ld]\n", p4, *p4, (void *)p4-memp);
    int *p5 = my_malloc(4);
    printf("p5: %p, *p5: %d, mem[%ld]\n", p5, *p5, (void *)p5-memp);
}
