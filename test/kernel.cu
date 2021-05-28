
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <stdio.h>
#include <GL/glew.h>
#include <GLFW/glfw3.h>
#include <cstdlib>
#include <stdlib.h>
#define WIDTH 512
#define HEIGHT 512
#define COUNT WIDTH*HEIGHT
#define MAX_TEMP 100

__global__ void kernel(double *temperatura,double *temperatura_bufor)
{
	//__shared__ double blok[16][16];

  int x = threadIdx.x + blockIdx.x * blockDim.x;
  int y = threadIdx.y + blockIdx.y * blockDim.y;

  int offset = x + y * blockDim.x * gridDim.x;

   
	  if(x != 0 && x != gridDim.x*blockDim.x-1 && y != 0 && y != gridDim.y*blockDim.y-1){

		  temperatura_bufor[offset] = (temperatura[offset-1]+temperatura[offset+1]+temperatura[offset+blockDim.x*gridDim.x]+temperatura[offset-blockDim.x*gridDim.x])/4;
	  }else
	  {
		  temperatura_bufor[offset] = temperatura[offset];
	  }
		  __syncthreads();	
}

__global__ void colorToBitmap(float * pixels, double *temperatura)
  {
  
   
  int x = threadIdx.x + blockIdx.x * blockDim.x;
  int y = threadIdx.y + blockIdx.y * blockDim.y;

  int offset = x + y * blockDim.x * gridDim.x;

  float kolor = (float)(temperatura[offset]/MAX_TEMP);

	pixels[offset*3] = 0;
	pixels[offset*3+1] = kolor;
	pixels[offset*3+2] = 0 ;

  /*
  if(kolor > 0.7){
	  pixels[offset*3] = kolor;
	  pixels[offset*3+1] = 0;
	  pixels[offset*3+2] = 0 ;
  }else if(kolor < 0.7 && kolor > 0.4)
  {
	  pixels[offset*3] = kolor;
	  pixels[offset*3+1] = kolor;
	  pixels[offset*3+2] = 0;
  }else
  {
	  pixels[offset*3] = 0;
	  pixels[offset*3+1] = kolor;
	  pixels[offset*3+2] = 0.4-kolor ;
  }

  */
  

}

  void swap(double **bufor1, double **bufor2){
	  double *temp;
	  temp  = *bufor1;
	  *bufor2 = *bufor1;
	  *bufor1 = temp;
  }


void RenderScene(float * pixels);

int main()
{
	float * dst =  (float *)calloc(HEIGHT*WIDTH*3,sizeof(float));

	double *temperatura_h = (double *)calloc(HEIGHT*HEIGHT,sizeof(double));

	double *temperatura_d;
	cudaMalloc(&temperatura_d,HEIGHT*HEIGHT*sizeof(double));

	//warunki poczatkowe 100 st. na lewej scianie.
	for (int i = 0; i < WIDTH; i++)
	{ 
		for (int j = 0; j < HEIGHT; j++)
		{		
			if(j == 0)
			{
				int index = i*WIDTH+j;
				temperatura_h[index]=MAX_TEMP;
			}
		}
	}

	double *temperatura_bufor_d;
	cudaMalloc(&temperatura_bufor_d,HEIGHT*HEIGHT*sizeof(double));

	cudaMemcpy(temperatura_d,temperatura_h,WIDTH*HEIGHT*sizeof(double),cudaMemcpyHostToDevice);
	cudaMemcpy(temperatura_bufor_d,temperatura_h,WIDTH*HEIGHT*sizeof(double),cudaMemcpyHostToDevice);
	int size = WIDTH*HEIGHT*sizeof(float)*3; // BITMAPA RGB


  float* src;
  cudaMalloc(&src, size);
  
  dim3 blocks(WIDTH/16, HEIGHT/16);
  dim3 threads(16,16);
  for (int i = 0; i < 50000; i++)
  {
	kernel<<<blocks,threads>>>(temperatura_d,temperatura_bufor_d);
	swap(&temperatura_bufor_d,&temperatura_d);
  }
  
  colorToBitmap<<<blocks,threads>>>(src,temperatura_d);
  cudaMemcpy(dst, src, size, cudaMemcpyDeviceToHost);
  
  glfwInit();

    GLFWwindow* window = glfwCreateWindow(WIDTH, HEIGHT, "CudaC/C++ Boltzman Method", nullptr, nullptr);    
  
    glfwMakeContextCurrent(window);

    while (!glfwWindowShouldClose(window)){
     
		glClear(GL_COLOR_BUFFER_BIT);

		RenderScene(dst);

		glFlush();

		glfwSwapBuffers(window);

		glfwWaitEvents();
    }

  cudaFree(src);
  cudaFree(temperatura_bufor_d);
  cudaFree(temperatura_d);
  return 0;
}


void RenderScene(float * pixels){
	glDrawPixels(WIDTH, HEIGHT, GL_RGB, GL_FLOAT, pixels);
}



