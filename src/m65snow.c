
#include <stdio.h>
#include <stdlib.h>
#include <mega65.h>
#include <mega65-dma.h>
#include <conio.h>

#define MAX_FLAKES 50

byte *kbscan = 0xd610; // keyboard scanner

const byte width = 80;
const byte height = 25;
const unsigned int size = width * height;

const char *flakeSymbols = "*,.+";

typedef struct
{
	byte x;
	byte y;
	signed byte dir;
	bool isFree;
	char sign;
} snowflake;

byte delay[MAX_FLAKES];
byte currentCount[MAX_FLAKES];

snowflake *flakes;
byte canvas[size];

void mega65_io_enable()
{
	VICIV->KEY = 0x47;
	VICIV->KEY = 0x53;
	*PROCPORT_DDR = 64;
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

void initFlakes()
{
	byte i;
	byte r;
	flakes = malloc(MAX_FLAKES * sizeof(snowflake));
	for (i = 0; i < MAX_FLAKES; ++i)
	{
		(flakes + i)->x = 255;
		(flakes + i)->y = 255;
		(flakes + i)->isFree = true;
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
}

void canvasToScreen()
{
	memcpy_dma(DEFAULT_SCREEN, canvas, size);
}

void screenToCanvas()
{
	memcpy_dma(canvas, DEFAULT_SCREEN, size);
}

void addFlake()
{
	byte i;
	byte charIdx;
	snowflake *current;

	for (i = 0; i < MAX_FLAKES; ++i)
	{
		current = flakes + i;
		if (current->isFree)
		{
			charIdx = rand() & 3;
			current->x = (rand() & 63) + (rand() & 15);
			current->y = 0;
			current->sign = flakeSymbols[charIdx];
			current->isFree = false;
			delay[i] = (byte)(rand() & 3) + 2;
			currentCount[i] = delay[i];

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
		aFlake->isFree = true;
		return false;
	}

	newX = aFlake->x;
	newY = aFlake->y + 1;

	randomNumber = rand() & 15;
	if (randomNumber >= 8)
	{
		randomNumber = rand() & 31;
		if (randomNumber >= 28)
		{
			changeHorizontalDirection(aFlake);
		}
		// also move snowflake horizontally
		newX = aFlake->x + aFlake->dir;
	}

	if (newX >= width)
	{
		// flake exited on left or right side of screen
		aFlake->isFree = true;
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
		aFlake->isFree = true;
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
	byte i;
	snowflake *current;
	for (i = 0; i < MAX_FLAKES; ++i)
	{
		current = flakes + i;
		if (!current->isFree)
		{
			currentCount[i]--;
			if (currentCount[i] == 0)
			{
				currentCount[i] = delay[i];
				setCanvas(current->x, current->y, 32);
				if (doFlake(current))
				{
					setCanvas(current->x, current->y, current->sign);
				}
			}
		}
	}
}

void main(void)
{
	byte i;
	mega65_io_enable();
	initFlakes();
	bordercolor(0);
	bgcolor(0);

	clrscr();
	screenToCanvas();

	for (;;)
	{
		doFlakes();
		i = rand() & 127;
		if (i > 100)
		{
			addFlake();
		}
		for (i = 0; i < 20; ++i)
		{
			while (VICIII->RASTER)
				;
		}
		canvasToScreen();
	}
}
