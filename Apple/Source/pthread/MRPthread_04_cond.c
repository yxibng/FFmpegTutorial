#include <semaphore.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
//c99 support bool
#include <stdbool.h>
#include <stdarg.h>

// https://blog.csdn.net/lovecodeless/article/details/24929273

pthread_mutex_t packet_mutex;
pthread_mutex_t frame_mutex;

pthread_cond_t packet_notempty_cond;
pthread_cond_t packet_notfull_cond;
pthread_cond_t frame_notempty_cond;
pthread_cond_t frame_notfull_cond;

// 假设共有 50 个 packet 需要读取
const int PACKET_COUNTER = 50;
// 缓冲 10 packet
const int MAX_PACKET_BUFFER = 10;
// 缓冲 20 frame
const int MAX_FRAME_BUFFER = 20;

int packet_buffer_counter = 0;
int frame_buffer_counter  = 0;

void mrlog(const char * f, ...){
    va_list args;       //定义一个va_list类型的变量，用来储存单个参数
    va_start(args,f); //使args指向可变参数的第一个参数
    vprintf(f,args);  //必须用vprintf等带V的
    va_end(args);       //结束可变参数的获取
}

#define DEBUG_LOG_ON 0
#if DEBUG_LOG_ON
#define DEBUG(...) do { \
    mrlog(__VA_ARGS__);  \
} while (0)
#else
#define DEBUG(...) do { } while (0)
#endif

#define INFO(...) do { \
    mrlog(__VA_ARGS__);  \
} while (0)


void * read_func(void *ptr){
    int packet_counter = PACKET_COUNTER;
    while (packet_counter > 0)
    {
        DEBUG("read packet_mutex will lock\n");
        pthread_mutex_lock(&packet_mutex);
        DEBUG("read packet_mutex locked\n");
        if (packet_buffer_counter < MAX_PACKET_BUFFER){
            packet_buffer_counter++;
            packet_counter--;

            INFO("signal read a packet (%d)\n",packet_buffer_counter);
            pthread_cond_signal(&packet_notempty_cond);
            DEBUG("read packet_mutex unlocked\n");
            pthread_mutex_unlock(&packet_mutex);

        } else {
            INFO("packet buffer full, wait not full signal\n");
            ///packet buffer 满了等待buffer不满的信号
            pthread_cond_wait(&packet_notfull_cond,&packet_mutex);
            DEBUG("read packet_mutex unlocked\n");
            pthread_mutex_unlock(&packet_mutex);
        }
        usleep(50);
    }

    INFO("read packet EOF\n");
    return NULL;
}

void * decode_func(void *ptr){
    while (1)
    {
        bool need_decode = false;
        DEBUG("decode frame_mutex will lock\n");
        pthread_mutex_lock(&frame_mutex);
        DEBUG("decode frame_mutex locked\n");
        if (frame_buffer_counter < MAX_FRAME_BUFFER){
            need_decode = true;
        }
        DEBUG("decode frame_mutex unlocked\n");
        pthread_mutex_unlock(&frame_mutex);

        if (need_decode)
        {
            DEBUG("decode packet_mutex will lock\n");
            pthread_mutex_lock(&packet_mutex);
            DEBUG("decode packet_mutex locked\n");
            if (packet_buffer_counter == 0)
            {
                INFO("packet buffer is empty,wait not empty signal\n");
                pthread_cond_wait(&packet_notempty_cond,&packet_mutex);
            }

            packet_buffer_counter--;
            INFO("dequeue to decode (%d),signal packet not full\n",packet_buffer_counter);
            pthread_cond_signal(&packet_notfull_cond);
            pthread_mutex_unlock(&packet_mutex);
            
            pthread_mutex_lock(&frame_mutex);
            frame_buffer_counter++;
            INFO("queue frame (%d),signal not empty\n",frame_buffer_counter);
            pthread_cond_signal(&frame_notempty_cond);
            pthread_mutex_unlock(&frame_mutex);
            
        } else {
            ///frame buffer 满了要一直去发信号，让等待的显示线程继续往下执行
            pthread_cond_signal(&frame_notempty_cond);
            pthread_mutex_lock(&frame_mutex);
            pthread_cond_wait(&frame_notfull_cond,&frame_mutex);
            pthread_mutex_unlock(&frame_mutex);
        }

        usleep(80);
    }

    return NULL;
}

void display_func(){

    int sum = 0;
    while (sum < PACKET_COUNTER)
    {
        pthread_mutex_lock(&frame_mutex);
        if (frame_buffer_counter > 0)
        {
            frame_buffer_counter--;
            sum++;
            INFO("display (%d/%d) frame \n",sum,PACKET_COUNTER);
            pthread_cond_signal(&frame_notfull_cond);
            pthread_mutex_unlock(&frame_mutex);
            usleep(400);
        } else {
            INFO("display wait frame not empty signal\n");
            pthread_cond_wait(&frame_notempty_cond,&frame_mutex);
            pthread_mutex_unlock(&frame_mutex);
        }
    }
}

int main (int argc,char **argv) {
    
    INFO("Hello Condition.\n");

    pthread_t read_pId,decode_pId;
    
    if (pthread_create(&read_pId,NULL,read_func,NULL) != 0)
    {
        exit(1);
    }

    if (pthread_create(&decode_pId,NULL,decode_func,NULL) != 0)
    {
        exit(1);
    }    
    
    if (pthread_cond_init(&packet_notempty_cond,NULL) != 0){
        INFO("pthread_cond_init packet_notempty_cond error\n");
        exit(1);
    }

    if (pthread_cond_init(&packet_notfull_cond,NULL) != 0){
        INFO("pthread_cond_init packet_notfull_cond error\n");
        exit(1);
    }

    if (pthread_cond_init(&frame_notempty_cond,NULL) != 0){
        INFO("pthread_cond_init frame_notempty_cond error\n");
        exit(1);
    }

    if (pthread_cond_init(&frame_notfull_cond,NULL) != 0){
        INFO("pthread_cond_init frame_notfull_cond error\n");
        exit(1);
    }

    if (pthread_mutex_init(&packet_mutex,NULL) != 0){
        exit(1);
    }

    if (pthread_mutex_init(&frame_mutex,NULL) != 0){
        exit(1);
    }

    display_func();

    pthread_cond_destroy(&packet_notempty_cond);
    pthread_cond_destroy(&packet_notfull_cond);
    pthread_cond_destroy(&frame_notempty_cond);
    pthread_cond_destroy(&frame_notfull_cond);
    pthread_mutex_destroy(&packet_mutex);
    pthread_mutex_destroy(&frame_mutex);
    
    INFO("Bye Condition.\n");
    return 0;
}