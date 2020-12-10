
#include <stdio.h>
#include <stdlib.h>
#include <mega65.h>
#include <mega65-dma.h>
#include <conio.h>

#include "greet.c"

const unsigned int maxFlakes = 200;

byte *kbscan = 0xd610; // keyboard scanner

const byte width = 89;
const byte height = 71;
const unsigned int size = width*height;

const char *flakeSymbols = "*+,.";

long textScreen = 0x40000;

typedef struct
{
	byte x;
	byte y;
	byte delay;
	byte currentCount;
	signed byte dir;
	byte isFree;
	char sign;
} snowflake;

snowflake *flakes;
byte canvas[size];
byte color[size];
byte background[size];

signed byte windDir;
unsigned int windCooldown;
unsigned int windDuration;

// DMA list entry for filling data in the 1MB memory space
struct DMA_LIST_F018B memfill_dma_command4 = {
	DMA_COMMAND_FILL, // command
	0,				  // count
	0,				  // source
	0,				  // source bank
	0,				  // destination
	0,				  // destination bank
	0,				  // sub-command
	0				  // modulo-value
};

// DMA list entry with options for copying data in the 256MB memory space
// Contains DMA options options for setting MB followed by DMA_LIST_F018B struct.
char memfill_dma_command256[] = {
	DMA_OPTION_SRC_MB, 0x00,  // Set MB of source address
	DMA_OPTION_DEST_MB, 0x00, // Set MB of destination address
	DMA_OPTION_FORMAT_F018B,  // Use F018B list format
	DMA_OPTION_END,			  // End of options
							  // struct DMA_LIST_F018B
	DMA_COMMAND_FILL,		  // command
	0, 0,					  // count
	0, 0,					  // source
	0,						  // source bank
	0, 0,					  // destination
	0,						  // destination bank
	0,						  // sub-command
	0, 0					  // modulo-value
};

void memfill_dma256(char dest_mb, char dest_bank, void *dest, char src_mb, char src_bank, void *src, unsigned int num)
{
	// Remember current F018 A/B mode
	char dmaMode = DMA->EN018B;
	// Set up command
	memfill_dma_command256[1] = src_mb;
	memfill_dma_command256[3] = dest_mb;
	struct DMA_LIST_F018B *f018b = (struct DMA_LIST_F018B *)(&memfill_dma_command256[6]);
	f018b->count = num;
	f018b->src_bank = src_bank;
	f018b->src = src;
	f018b->dest_bank = dest_bank;
	f018b->dest = dest;
	// Set F018B mode
	DMA->EN018B = 1;
	// Set address of DMA list
	DMA->ADDRMB = 0;
	DMA->ADDRBANK = 0;
	DMA->ADDRMSB = > memfill_dma_command256;
	// Trigger the DMA (with option lists)
	DMA->ETRIG = < memfill_dma_command256;
	// Re-enable F018A mode
	DMA->EN018B = dmaMode;
}

void memfill_dma4(char dest_bank, void *dest, char src_bank, void *src, unsigned int num)
{
	// Remember current F018 A/B mode
	char dmaMode = DMA->EN018B;
	// Set up command
	memfill_dma_command4.count = num;
	memfill_dma_command4.src_bank = src_bank;
	memfill_dma_command4.src = src;
	memfill_dma_command4.dest_bank = dest_bank;
	memfill_dma_command4.dest = dest;
	// Set F018B mode
	DMA->EN018B = 1;
	// Set address of DMA list
	DMA->ADDRMB = 0;
	DMA->ADDRBANK = 0;
	DMA->ADDRMSB = > &memfill_dma_command4;
	// Trigger the DMA (without option lists)
	DMA->ADDRLSBTRIG = < &memfill_dma_command4;
	// Re-enable F018A mode
	DMA->EN018B = dmaMode;
}

void mega65_io_enable()
{
	VICIV->KEY = 0x47;
	VICIV->KEY = 0x53;
	*PROCPORT_DDR = 65;
}

char cgetc()
{
	char res;
	while (*kbscan == 0)
		;
	res = *kbscan;
	*kbscan = 0;
	return res;
}

void initScreen()
{

	mega65_io_enable();

	VICIV->RASLINE0 &= 127; // force pal mode

	VICIV->CONTROLB |= 128; // enable 80chars
	VICIV->CONTROLB |= 8;	// enable interlace

	VICIV->TBDRPOS_LO = 18; // disable top border
	VICIV->TEXTYPOS_LO = 1; // text y pos

	VICIV->BBDRPOS_HI = 2;
	VICIV->BBDRPOS_LO = 70; // disable bottom border

	VICIV->ROWCOUNT = height - 1;

	VICIV->SIDBDRWD_LO = 44; // reduce side border
	VICIV->TEXTXPOS_LO = 44; // text x pos

	VICIV->CHRCOUNT = width; // characters per row
	VICIV->CHARSTEP_LO = width;

	// set screen pointer
	VICIV->SCRNPTR_HIHI = 0x00;
	VICIV->SCRNPTR_HILO = 0x04;
	VICIV->SCRNPTR_LOHI = 0x00;
	VICIV->SCRNPTR_LOLO = 0x00;

	// clear char & text ram

	memcpy_dma(background,frame0000+2,size);
	// memfill_dma4(0, background, 0, 32, size);
	// memfill_dma256(0xff, 0x08, 0x0000, 0x00, 0x00, 01, size);
}

void initFlakes()
{
	unsigned int i;
	byte r;
	flakes = malloc(maxFlakes * sizeof(snowflake));
	for (i = 0; i < maxFlakes; ++i)
	{
		(flakes + i)->x = 255;
		(flakes + i)->y = 255;
		(flakes + i)->isFree = 1;
		r = rand() & 15;
		if (r > 8)
		{
			(flakes + i)->dir = 1;
		}
		else
		{
			(flakes + i)->dir = -1;
		}
	}

	windDir = 0;
	windCooldown = 500 + (rand() & 511);
	windDuration = 0;
}

void canvasToScreen()
{
	memcpy_dma4(4, 0, 0, canvas, size);
	memcpy_dma256(0xff,0x08,0x000,0x00,0x00,color,size);

}

void changeWindDir()
{
	byte shouldChangeDir;

	if (windCooldown > 0)
	{
		windCooldown--;
		return;
	}

	if (windDuration > 0)
	{
		windDuration--;
		if (windDuration == 0)
		{
			windDir = 0;
			windCooldown = (unsigned int)200 + (rand() & 255);
		}
		return;
	}

	shouldChangeDir = rand() & 255;

	if (shouldChangeDir > 200)
	{

		if (rand() & 1)
		{
			windDir = -1;
		}
		else
		{
			windDir = 1;
		}

		windDuration = 100 + (rand() & 127);
	}
}

#define DIR_TOP 0
#define DIR_LEFT 1
#define DIR_RIGHT 2

void addFlake(byte dir)
{
	unsigned int i;
	byte charIdx;
	snowflake *current;

	for (i = 0; i < maxFlakes; ++i)
	{
		current = flakes + i;
		if (current->isFree)
		{

			charIdx = rand() & 3;
			if (dir == DIR_TOP)
			{
				current->x = (rand() & 63) + (rand() & 15) + (rand() & 7) + (rand() & 3);
				current->y = 0;
			}
			else if (dir == DIR_LEFT)
			{
				current->x = 0;
				current->y = (rand() & 63) + (rand() & 7);
			}
			else if (dir == DIR_RIGHT)
			{
				current->x = width - 1;
				current->y = (rand() & 63) + (rand() & 7);
			}

			current->sign = flakeSymbols[charIdx];
			current->isFree = 0;
			current->delay = charIdx + 2;
			current->currentCount = current->delay;
			current->dir = 0;

			return;
		}
	}
}

void growSnowHeapAt(byte x, byte y)
{
	// TODO
	// setCanvas(x,y,160);
}

void changeHorizontalDirection(snowflake *aFlake)
{
	if (aFlake->dir == -1)
	{
		aFlake->dir = 1;
	}
	else
	{
		aFlake->dir = -1;
	}
}

bool doFlake(snowflake *aFlake)
{
	byte randomNumber;
	byte newX;
	byte newY;
	byte c;

	if (aFlake->y >= height - 1)
	{
		// flake has reached bottom of screen
		growSnowHeapAt(aFlake->x, aFlake->y);
		aFlake->isFree = 1;
		return false;
	}

	newX = aFlake->x + windDir;
	newY = aFlake->y + 1;

	if (windDir == 0)
	{
		randomNumber = rand() & 127;

		if (randomNumber >= 110)
		{
			// also move snowflake horizontally
			randomNumber = rand() & 255;
			if (randomNumber >= 230)
			{
				changeHorizontalDirection(aFlake);
			}
			newX = aFlake->x + aFlake->dir;
		}
	}

	if (newX >= width)
	{
		// flake exited on left or right side of screen
		aFlake->isFree = 1;
		return false;
	}

	// something already there?

	if (canvasAt(newX, newY) == 160)
	{
		newX = aFlake->x;
	}

	if (canvasAt(newX, newY) == 160)
	{
		// check if we're sticking
		randomNumber = rand() & 15;
		if (randomNumber > 8)
		{
			growSnowHeapAt(aFlake->x, aFlake->y);
		}
		aFlake->isFree = 1;
		return false;
	}

	aFlake->x = newX;
	aFlake->y = newY;

	return true;
}

void setCanvas(byte x, byte y, char s)
{
	unsigned int adr;
	adr = (unsigned int)y * width;
	adr += (unsigned int)x;
	canvas[adr] = s;
	color[adr]=1; // white
}

byte canvasAt(byte x, byte y)
{
	unsigned int adr;
	adr = (unsigned int)y * width;
	adr += (unsigned int)x;
	return canvas[adr];
}

void doFlakes()
{
	unsigned int i;
	snowflake *current;

	memcpy_dma(canvas,background,size);
	memcpy_dma(color,frame0000+2+size,size);

	for (i = 0; i < maxFlakes; ++i)
	{
		current = flakes + i;
		if (!current->isFree)
		{
			if (current->currentCount-- == 0)
			{
				current->currentCount = current->delay;
				doFlake(current);
			}
			setCanvas(current->x, current->y, current->sign);
		}
	}
}

void main(void)
{
	byte i;
	clrscr();
	initScreen();
	initFlakes();
	bordercolor(5);
	bgcolor(0);

	for (;;)
	{
		doFlakes();
		i = rand() & 255;
		if (i > 200)
		{
			addFlake(DIR_TOP);
			if (windDir == -1)
			{
				addFlake(DIR_RIGHT);
			}
			else if (windDir == 1)
			{
				addFlake(DIR_LEFT);
			}
		}
		for (i = 0; i < 200; ++i)
		{
			while (VICIII->RASTER)
				;
		}
		canvasToScreen();
		changeWindDir();
	}
}
