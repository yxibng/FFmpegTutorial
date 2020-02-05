#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

// 线程共享缓冲区
char Buffer[20];

#define USE_MUTEX 1

#if USE_MUTEX

// 使用互斥量，做线程同步
pthread_mutex_t mutex;

void *safe_task(void *ptr){
    const char c = *(char *)ptr;
    for (int i = 0; i < 5; i++)
    {
        printf("%c thread will write to buffer(%d)\n",c,i);
        char *str = Buffer;
        pthread_mutex_lock(&mutex);
        for (int i = 0; i < 10; i++)
        {
            *str++ = c;
            usleep(300);
        }
        *str = 0;
        pthread_mutex_unlock(&mutex);
        printf("Buffer:%s\n",Buffer);
        sleep(1);
    }
}

#else

void *unsafe_task(void *ptr){
    const char c = *(char *)ptr;
    for (int i = 0; i < 5; i++)
    {
        printf("%c thread will write to buffer(%d)\n",c,i);
        char *str = Buffer;
        for (int i = 0; i < 10; i++)
        {
            *str++ = c;
            usleep(300);
        }
        *str = 0;
        printf("Buffer:%s\n",Buffer);
        sleep(1);
    }
}

#endif

int main (int argc,char **argv) {
    
    printf("Hello Pthread.\n");

    pthread_t pId,pId2;
    #if USE_MUTEX
    void *(*func)(void *) = &safe_task;
    #else
    void *(*func)(void *) = &unsafe_task;
    #endif

    if (pthread_create(&pId,NULL,func,(void *)"A") != 0)
    {
        exit(1);
    }
    
    if (pthread_create(&pId2,NULL,func,(void *)"B") != 0)
    {
        exit(1);
    }

    #if USE_MUTEX
    if (pthread_mutex_init(&mutex,NULL) != 0){
        exit(1);
    }
    #endif

    //当前线程等待 pId 线程执行完
    pthread_join(pId,NULL);
    pthread_join(pId2,NULL);

    #if USE_MUTEX
    pthread_mutex_destroy(&mutex);
    #endif

    printf("Bye Pthread.\n");
    return 0;
}