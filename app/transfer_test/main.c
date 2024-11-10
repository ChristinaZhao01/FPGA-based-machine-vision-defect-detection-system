

#include <sys/mman.h>
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <linux/ioctl.h>
#include <unistd.h>
#include <string.h>

#define soc_cv_av

#include "hwlib.h"
#include "socal/socal.h"
#include "socal/hps.h"
#include "hps_0.h"

#define HW_REGS_BASE (ALT_STM_OFST)
#define HW_REGS_SPAN (0x04000000)
#define HW_REGS_MASK (HW_REGS_SPAN - 1)

#define AMM_WR_MAGIC 'x'
#define AMM_WR_CMD_DMA_BASE _IOR(AMM_WR_MAGIC, 0x1a, int)
#define AMM_WR_CMD_PHY_BASE _IOR(AMM_WR_MAGIC,0x1b,int)

#define IMG_WIDTH  400
#define IMG_HEIGHT 320
#define BURST_LEN 48

#define IMG_BUF_SIZE IMG_WIDTH * IMG_HEIGHT * 3

static unsigned char *transfer_data_base = NULL;
static unsigned char *p_transfer_data_base = NULL;
static volatile unsigned int *dvp_ddr3_cfg_base = NULL;//寄存器
static volatile unsigned int *ddr3_vga_cfg_base = NULL;//寄存器

//#define ERRINDEXLOG

int fpga_init(void)
{
	void *per_virtual_base;
	int transfer_fd;
	int mem_fd;

	system("insmod amm_wr_drv.ko");

	transfer_fd = open("/dev/amm_wr", (O_RDWR|O_SYNC));
	if(transfer_fd == -1)
	{
		printf("open amm_wr is failed\n");
		return(0);
	}
	mem_fd = open("/dev/mem", (O_RDWR|O_SYNC));
	if(mem_fd == -1)
	{
		printf("open mmu is failed\n");
		return(0);
	}

	ioctl(transfer_fd, AMM_WR_CMD_DMA_BASE, &p_transfer_data_base);
	printf("p_transfer_data_base = %x\n", p_transfer_data_base);

	transfer_data_base = (unsigned char *)mmap(NULL, IMG_BUF_SIZE * 3, (PROT_READ | PROT_WRITE), MAP_SHARED, mem_fd, p_transfer_data_base);

	per_virtual_base = (unsigned int*)mmap(NULL, HW_REGS_SPAN, (PROT_READ | PROT_WRITE), MAP_SHARED, mem_fd, HW_REGS_BASE);

	dvp_ddr3_cfg_base = (unsigned int *)(per_virtual_base + ((unsigned long)(ALT_LWFPGASLVS_OFST + DVP_DDR3_0_BASE) & (unsigned long)(HW_REGS_MASK)));
	ddr3_vga_cfg_base = (unsigned int *)(per_virtual_base + ((unsigned long)(ALT_LWFPGASLVS_OFST + DDR3_VGA_0_BASE) & (unsigned long)(HW_REGS_MASK)));

	//config dvp_ddr3
	*dvp_ddr3_cfg_base = p_transfer_data_base;
	*(dvp_ddr3_cfg_base + 1) = IMG_BUF_SIZE;
	*(dvp_ddr3_cfg_base + 2) = 0x00000000;

	//config ddr3_vga
	*ddr3_vga_cfg_base = p_transfer_data_base + IMG_BUF_SIZE;
	*(ddr3_vga_cfg_base + 1) = IMG_BUF_SIZE;
	*(ddr3_vga_cfg_base + 2) = 0x00000000;

	usleep(1000000);

	return 1;
}

int main ()
{
	unsigned char buf[IMG_BUF_SIZE];

	if(fpga_init() != 1)
	{
		printf("fpga init failed!\n");
	}

	//dvp_ddr3开始工作
	*(dvp_ddr3_cfg_base + 2) = 0x00000001;
	//ddr3_vga开始工作
	*(ddr3_vga_cfg_base + 2) = 0x00000001;

	while(1)
	{
		//获取一帧图像
		*(dvp_ddr3_cfg_base + 3) = 0x00000001;
		while(1)
		{
			if(*(dvp_ddr3_cfg_base + 3) == 0x00000000)
				break;
		}
		memcpy(buf, transfer_data_base, IMG_BUF_SIZE);

		//输出一帧图像
		if(((*(ddr3_vga_cfg_base + 3)) & 0x00000003) == 0x00000002)
		{
			printf("write buffer0\n");
			memcpy(transfer_data_base + IMG_BUF_SIZE, transfer_data_base, IMG_BUF_SIZE);
			memcpy(buf, transfer_data_base + IMG_BUF_SIZE, IMG_BUF_SIZE);
			*(ddr3_vga_cfg_base + 3) = *(ddr3_vga_cfg_base + 3) | 0x00000001;
		}
		else if(((*(ddr3_vga_cfg_base + 3)) & 0x00000003) == 0x00000001)
		{
			printf("write buffer1\n");
			memcpy(transfer_data_base + IMG_BUF_SIZE * 2, transfer_data_base, IMG_BUF_SIZE);
			memcpy(buf, transfer_data_base + IMG_BUF_SIZE * 2, IMG_BUF_SIZE);
			*(ddr3_vga_cfg_base + 3) = *(ddr3_vga_cfg_base + 3) | 0x00000002;
		}

		usleep(1000);
	}
	return 0;
}




