#include <semaphore.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
//c99 support bool
#include <stdbool.h>

// https://blog.csdn.net/lovecodeless/article/details/24919511

#define FILE_MODE (S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH)

pthread_mutex_t packet_mutex;
pthread_mutex_t frame_mutex;

sem_t * packet_sem;
sem_t * frame_sem;

// 假设共有 50 个 packet 需要读取
const int PACKET_COUNTER = 50;
// 缓冲 10 packet
const int MAX_PACKET_BUFFER = 10;
// 缓冲 20 frame
const int MAX_FRAME_BUFFER = 20;

int packet_buffer_counter = 0;
int frame_buffer_counter  = 0;

void * read_func(void *ptr){
    int packet_counter = PACKET_COUNTER;
    while (packet_counter > 0)
    {
        pthread_mutex_lock(&packet_mutex);
        if (packet_buffer_counter < MAX_PACKET_BUFFER){
            packet_buffer_counter++;
            packet_counter--;
            printf("read a packet (%d)\n",packet_buffer_counter);
            sem_post(packet_sem);
        } else {
            printf("packet buffer is full(%d)\n",packet_buffer_counter);
        }
        pthread_mutex_unlock(&packet_mutex);

        usleep(50);
    }

    printf("read packet EOF\n");
    return NULL;
}

void * decode_func(void *ptr){
    while (1)
    {
        bool need_decode = false;
        pthread_mutex_lock(&frame_mutex);
        if (frame_buffer_counter < MAX_FRAME_BUFFER){
            need_decode = true;
        }
        pthread_mutex_unlock(&frame_mutex);

        if (need_decode)
        {
            sem_wait(packet_sem);
            pthread_mutex_lock(&packet_mutex);
            usleep(80);
            packet_buffer_counter--;
            printf("dequeue packet to decode (%d)\n",packet_buffer_counter);
            pthread_mutex_unlock(&packet_mutex);

            pthread_mutex_lock(&frame_mutex);
            frame_buffer_counter++;
            sem_post(frame_sem);
            printf("queue frame (%d)\n",frame_buffer_counter);
            pthread_mutex_unlock(&frame_mutex);
        }
    }
    return NULL;
}

void display_func(){

    int sum = 0;
    while (sum < PACKET_COUNTER)
    {
        sem_wait(frame_sem);
        pthread_mutex_lock(&frame_mutex);
        frame_buffer_counter--;
        sum++;
        printf("display (%d/%d) frame \n",sum,PACKET_COUNTER);
        pthread_mutex_unlock(&frame_mutex);
        usleep(400);
    }
}

int main (int argc,char **argv) {
    
    printf("Hello Samaphore.\n");

    pthread_t read_pId,decode_pId;
    
    if (pthread_create(&read_pId,NULL,read_func,NULL) != 0)
    {
        exit(1);
    }
    
    if (pthread_create(&decode_pId,NULL,decode_func,NULL) != 0)
    {
        exit(1);
    }

    packet_sem = sem_open("packet_sem",O_RDWR|O_CREAT,FILE_MODE,0);
    if (SEM_FAILED == packet_sem){
        printf("sem_open packet_sem error\n");
        exit(1);
    }

    frame_sem = sem_open("/frame_sem",O_RDWR|O_CREAT,FILE_MODE,0);
    if (SEM_FAILED == frame_sem){
        printf("sem_open frame_sem error\n");
        exit(1);
    }

    // if (sem_init(&packet_sem,0,0) != 0){
    //     printf("sem_init packet_sem error\n");
    //     exit(1);
    // }
    
    // if (sem_init(&frame_sem,0,0) != 0){
    //     printf("sem_init frame_sem error\n");
    //     exit(1);
    // }

    if (pthread_mutex_init(&packet_mutex,NULL) != 0){
        exit(1);
    }

    if (pthread_mutex_init(&frame_mutex,NULL) != 0){
        exit(1);
    }

    display_func();

    sem_unlink("packet_sem");
    sem_unlink("frame_sem");
    pthread_mutex_destroy(&packet_mutex);
    pthread_mutex_destroy(&frame_mutex);
    
    printf("Bye Samaphore.\n");
    return 0;
}