// Sketch to drive a hacked 80x7 2-color LED display
// By Matt Mets

// The LED control signals are arranged in a 160 column by 7 row matrix.  The column is
// made of a giant shift register, with interleved green and red bytes.  The rows are directly
// driven via digital pins.

// Hardware SPI hints from:
// http://www.arduino.cc/en/Tutorial/SPIDigitalPot


// 5x7 character font from http://heim.ifi.uio.no/haakoh/avr/font.h
// 0-25: letters
// 26-36: numbers, style A
// 37-47: numbers, style B
const int fontCount = 46;
const unsigned char font[46][5] = {
  {0x3f, 0x48, 0x48, 0x48, 0x3f},
  {0x7f, 0x49, 0x49, 0x49, 0x36},
  {0x3e, 0x41, 0x41, 0x41, 0x22},
  {0x7f, 0x41, 0x41, 0x22, 0x1c},
  {0x7f, 0x49, 0x49, 0x49, 0x41},
  {0x7f, 0x48, 0x48, 0x48, 0x40},
  {0x3e, 0x41, 0x49, 0x49, 0x2e},
  {0x7f, 0x08, 0x08, 0x08, 0x7f},
  {0x00, 0x41, 0x7f, 0x41, 0x00},
  {0x06, 0x01, 0x01, 0x01, 0x7e},
  {0x7f, 0x08, 0x14, 0x22, 0x41},
  {0x7f, 0x01, 0x01, 0x01, 0x01},
  {0x7f, 0x20, 0x10, 0x20, 0x7f},
  {0x7f, 0x10, 0x08, 0x04, 0x7f},
  {0x3e, 0x41, 0x41, 0x41, 0x3e},
  {0x7f, 0x48, 0x48, 0x48, 0x30},
  {0x3e, 0x41, 0x45, 0x42, 0x3d},
  {0x7f, 0x48, 0x4c, 0x4a, 0x31},
  {0x31, 0x49, 0x49, 0x49, 0x46},
  {0x40, 0x40, 0x7f, 0x40, 0x40},
  {0x7e, 0x01, 0x01, 0x01, 0x7e},
  {0x7c, 0x02, 0x01, 0x02, 0x7c},
  {0x7f, 0x02, 0x04, 0x02, 0x7f},
  {0x63, 0x14, 0x08, 0x14, 0x63},
  {0x60, 0x10, 0x0f, 0x10, 0x60},
  {0x43, 0x45, 0x49, 0x51, 0x61},
  {0x3e, 0x45, 0x49, 0x51, 0x3e},
  {0x00, 0x10, 0x20, 0x7f, 0x00},
  {0x47, 0x49, 0x49, 0x49, 0x31},
  {0x42, 0x49, 0x59, 0x69, 0x46},
  {0x08, 0x18, 0x28, 0x7f, 0x08},
  {0x71, 0x49, 0x49, 0x49, 0x46},
  {0x3e, 0x49, 0x49, 0x49, 0x06},
  {0x40, 0x47, 0x48, 0x50, 0x60},
  {0x36, 0x49, 0x49, 0x49, 0x36},
  {0x30, 0x49, 0x49, 0x49, 0x3e},
  {0x7f, 0x41, 0x41, 0x41, 0x7f},
  {0x00, 0x00, 0x00, 0x00, 0x7f},
  {0x4f, 0x49, 0x49, 0x49, 0x79},
  {0x49, 0x49, 0x49, 0x49, 0x7f},
  {0x78, 0x08, 0x08, 0x08, 0x7f},
  {0x79, 0x49, 0x49, 0x49, 0x4f},
  {0x7f, 0x49, 0x49, 0x49, 0x4f},
  {0x40, 0x40, 0x40, 0x40, 0x7f},
  {0x7f, 0x49, 0x49, 0x49, 0x7f},
  {0x79, 0x49, 0x49, 0x49, 0x7f}};

// Get an index into the current font corresponding to the 
// @letter    ASCII character to convert
// @return    index into the current font corresponding to the letter,
//            or 255 if not found.
unsigned char fontGetAsciiChar(char letter)
{
  if (letter >= 65 && letter <= 90) {
    // Uppercase
    return letter - 65;
  }
  else if (letter >= 97 && letter <= 122) {
    // Lowercase
    return letter - 97;
  }
  else if (letter >= 48 && letter <= 57) {
    // Number
    return letter - 48 + 26;
  }
  else {
    // we don't have a character for that, sorry!
    return 255;
  }
}


// Video buffer 80x7
// green is arrays 0-6, red is 7-13
unsigned char videoBuffer[14][10];

// 7 pins that turn on the rows
unsigned char rowPins[] = {2, 3, 4, 5, 6, 7, 8};

// Colored stripes
unsigned char testPatternB[] = {0xb6, 0x6d, 0xdb, 0xb6, 0x6d, 0xdb, 0xb6, 0x6d, 0xdb, 0xb6,
                                0x6d, 0xdb, 0xb6, 0x6d, 0xdb, 0xb6, 0x6d, 0xdb, 0xb6, 0x6d,
                                0xdb, 0xb6, 0x6d, 0xdb, 0xb6, 0x6d, 0xdb, 0xb6, 0x6d};


#define DATAOUT 11      //MOSI
#define DATAIN 12       //MISO - not used, but part of builtin SPI
#define SPICLOCK  13    //sck


char spi_transfer(volatile char data)
{
  SPDR = data;                    // Start the transmission
  while (!(SPSR & (1<<SPIF))) {}  // Wait the end of the transmission
                                  // TODO: interrupt-based display
  return SPDR;                    // return the received byte
}


//  Draw a letter at any point in the display buffer
//  letter  in ASCII
//  offset  in leds from the origin
//  color   String color (0 = green, 1 = red, 2 = yellow)
void drawChar(char letter, unsigned char offset, unsigned char color)
{
  // First, convert the ASCII letter to a font offset
  // (kludge for current font)
  unsigned char fontOffset = fontGetAsciiChar(letter);
  if (fontOffset == 255) { return; }
  
  // Fix the color
  color += 1;

  unsigned char alignedCol = 0;
  unsigned char alignedOffset = 0;
  
  for (int row = 0; row < 7; row++) {
    // Calculate which byte the character starts on, and the bit offset from that byte
    alignedCol = offset/8;
    alignedOffset = offset%8;
    
    for (int col = 0; col < 5; col++) {
      if( color & 0x1) {
        videoBuffer[row][alignedCol] |= ((font[fontOffset][col] >> row) & 0x1) << alignedOffset;
      }
      if( color & 0x2) {
        videoBuffer[row + 7][alignedCol] |= ((font[fontOffset][col] >> row) & 0x1) << alignedOffset;
      }
      
      // Advance to the next offset
      alignedOffset++;
      
      // If we walk out of the current column byte, advance to the next
      if (alignedOffset > 7) {
        alignedOffset = 0;
        alignedCol++;
      }
    }
  }
}


// Draw a string at any point into the buffer
//
//  string  C-style string
//  length  length of said string
//  offset  byte offset to display string
//  color   String color (0 = green, 1 = red, 2 = yellow)
void drawString(char* string, char length, int offset, unsigned char color)
{
  for (int i = 0; i < length; i++) {
    drawChar(string[i], offset, color);
    offset+=6;
  }
} 


// Clear the video buffer
void clearVideoBuffer()
{
  for (int i = 0; i < 14; i++) {
    for (int j = 0; j < 10; j++) {
      videoBuffer[i][j] = 0;
    }
  }
}


// TODO: Make this interrupt-based!
void drawVideoBuffer()
{
  // For each row
  for (int row = 0; row < 7; row++) {
    // for each column
    for (int col = 0; col < 10; col++) {
      // Green
      spi_transfer(videoBuffer[row][9-col]);
      
      // Then red
      spi_transfer(videoBuffer[row+7][9-col]);
    }
    
    digitalWrite(rowPins[row], HIGH);
    delayMicroseconds(500);
    digitalWrite(rowPins[row], LOW);    
  }
}


void setupVideoBuffer()
{
  byte clr;
  pinMode(DATAOUT, OUTPUT);
  pinMode(DATAIN, INPUT);
  pinMode(SPICLOCK,OUTPUT);
  
  pinMode(10, OUTPUT);
  digitalWrite(10, LOW);
  
  // SPCR = 01010000
  //interrupt disabled,spi enabled,msb 1st,master,clk low when idle,
  //sample on leading edge of clk,system clock/4 (fastest)
  SPCR = (1<<SPE)|(1<<MSTR);
  clr=SPSR;
  clr=SPDR;
  delay(10);
  
  // Setup row select lines
  for (int i = 0; i < sizeof(rowPins); i++) {
    pinMode(rowPins[i], OUTPUT);
    digitalWrite(rowPins[i], LOW);
  }

  clearVideoBuffer();
}


// Initialize the IO ports
void setup()
{
  setupVideoBuffer();
  
  Serial.begin(9600);
}
 

// Main loop
void loop()
{
  for (int i = 0; i < 16; i++) {
    clearVideoBuffer();
    drawString("HackPGH", 7, 0+i, 0);
    drawString("FTW", 3, 48+i, 2);
    for (int j = 0; j < 25; j++) {
      drawVideoBuffer();
    }
  }

  for (int i = 14; i > 0; i--) {
    clearVideoBuffer();
    drawString("HackPGH", 7, 0+i, 1);
    drawString("FTW", 3, 48+i, 2);
    for (int j = 0; j < 25; j++) {
      drawVideoBuffer();
    }
  }
}
