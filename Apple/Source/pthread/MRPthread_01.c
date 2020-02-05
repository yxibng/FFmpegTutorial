#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

void *task(void *ptr){
    char *const str = (char * const)ptr;
    for (int i = 0; i < 5; i++)
    {
        printf("%s running,count: %d\n",str,i);
        sleep(1);
    }
}

int main (int argc,char **argv) {
    
    printf("Hello Pthread.\n");

    pthread_t pId;

    if (pthread_create(&pId,NULL,task,(void *)"sub thread") != 0)
    {
        exit(1);
    }
    
    for (int i = 0; i < 2; i++)
    {
        printf("%s running,count: %d\n","main thread",i);
        sleep(1);
    }

    //当前线程等待 pId 线程执行完
    pthread_join(pId,NULL);
    printf("Bye Pthread.\n");
    return 0;
}