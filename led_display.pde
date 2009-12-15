#include <avr/pgmspace.h>

// Sketch to drive a hacked 80x7 2-color LED display
// By Matt Mets

// The LED control signals are arranged in a 160 column by 7 row matrix.  The column is
// made of a giant shift register, with interleved green and red bytes.  The rows are directly
// driven via digital pins.

// Hardware SPI hints from:
// http://www.arduino.cc/en/Tutorial/SPIDigitalPot

// Timer2 interrupt hints from:
// http://www.uchobby.com/index.php/2007/11/24/arduino-interrupts/

// 5x7 character font from:
// http://heim.ifi.uio.no/haakoh/avr/font.h

// Progmem stuff from:
// http://www.arduino.cc/en/Reference/PROGMEM


//////////////////////////////////////////////////////////////////////////////
// Hardware connections
//////////////////////////////////////////////////////////////////////////////

// Pins that control the row select lines
unsigned char rowPins[] = {2, 3, 4, 5, 6, 7, 8};

#define DATAOUT 11      //MOSI
#define DATAIN 12       //MISO - not used, but part of builtin SPI
#define SPICLOCK  13    //SCK



//////////////////////////////////////////////////////////////////////////////
// Font section
//////////////////////////////////////////////////////////////////////////////
#define FONT_BAD_CHARACTER 255

// 0: fail character (unicode block)
// 1 - 16:   <SPACE>!"#$%&'()*+,-./
// 17 - 26:  0123456789
// 27 - 33:  :;<=>?@
// 34 - 59:  capital letters
// 60 - 66:  [\]^_`
// 67 - 92:  lowercase letters
// 93 - 96:  {|}~
const int fontCount = 96;
const int fontWidth = 5;
prog_uchar font[96][5] PROGMEM = {
  {0x7f, 0x41, 0x41, 0x41, 0x7f}, // fail char (unicode block)
  {0x00, 0x00, 0x00, 0x00, 0x00}, // space
  {0x00, 0x00, 0x7d, 0x00, 0x00}, // !
  {0x00, 0x60, 0x00, 0x60, 0x00}, // "
  {0x14, 0x7f, 0X14, 0X7f, 0x14}, // #
  {0x14, 0x2a, 0x7f, 0x2a, 0x14}, // $
  {0x62, 0x64, 0x08, 0x13, 0x23}, // %
  {0x36, 0x49, 0x35, 0x02, 0x05}, // &
  {0x00, 0x00, 0x60, 0x00, 0x00}, // '
  {0x00, 0x1c, 0x22, 0x41, 0x00}, // (
  {0x00, 0x41, 0x22, 0x1c, 0x00}, // )
  {0x2a, 0x1c, 0x7f, 0x1c, 0x2a}, // *
  {0x00, 0x08, 0x1c, 0x08, 0x00}, // +
  {0x00, 0x0d, 0x0e, 0x00, 0x00}, // ,
  {0x04, 0x04, 0x04, 0x04, 0x04}, // -
  {0x00, 0x03, 0x03, 0x00, 0x00}, // .
  {0x01, 0x02, 0x0c, 0x10, 0x20}, // /
  {0x3e, 0x45, 0x49, 0x51, 0x3e}, // 0
  {0x00, 0x10, 0x20, 0x7f, 0x00}, // 1
  {0x47, 0x49, 0x49, 0x49, 0x31}, // 2
  {0x42, 0x49, 0x59, 0x69, 0x46}, // 3
  {0x08, 0x18, 0x28, 0x7f, 0x08}, // 4
  {0x71, 0x49, 0x49, 0x49, 0x46}, // 5
  {0x3e, 0x49, 0x49, 0x49, 0x06}, // 6
  {0x40, 0x47, 0x48, 0x50, 0x60}, // 7
  {0x36, 0x49, 0x49, 0x49, 0x36}, // 8
  {0x30, 0x49, 0x49, 0x49, 0x3e}, // 9
  {0x00, 0x36, 0x36, 0x00, 0x00}, // :
  {0x00, 0x37, 0x36, 0x00, 0x00}, // ;
  {0x08, 0x14, 0x14, 0x22, 0x22}, // <
  {0x14, 0x14, 0x14, 0x14, 0x14}, // =
  {0x22, 0x22, 0x14, 0x14, 0x08}, // >
  {0x20, 0x40, 0x4d, 0x48, 0x18}, // ?
  {0x3e, 0x41, 0x5d, 0x55, 0x1d}, // @
  {0x3f, 0x48, 0x48, 0x48, 0x3f}, // A
  {0x7f, 0x49, 0x49, 0x49, 0x36}, // B
  {0x3e, 0x41, 0x41, 0x41, 0x22}, // C
  {0x7f, 0x41, 0x41, 0x22, 0x1c}, // D
  {0x7f, 0x49, 0x49, 0x49, 0x41}, // E
  {0x7f, 0x48, 0x48, 0x48, 0x40}, // F
  {0x3e, 0x41, 0x49, 0x49, 0x2e}, // G
  {0x7f, 0x08, 0x08, 0x08, 0x7f}, // H
  {0x00, 0x41, 0x7f, 0x41, 0x00}, // I
  {0x06, 0x01, 0x01, 0x01, 0x7e}, // J
  {0x7f, 0x08, 0x14, 0x22, 0x41}, // K
  {0x7f, 0x01, 0x01, 0x01, 0x01}, // L
  {0x7f, 0x20, 0x10, 0x20, 0x7f}, // M
  {0x7f, 0x10, 0x08, 0x04, 0x7f}, // N
  {0x3e, 0x41, 0x41, 0x41, 0x3e}, // O
  {0x7f, 0x48, 0x48, 0x48, 0x30}, // P
  {0x3e, 0x41, 0x45, 0x42, 0x3d}, // Q
  {0x7f, 0x48, 0x4c, 0x4a, 0x31}, // R
  {0x31, 0x49, 0x49, 0x49, 0x46}, // S
  {0x40, 0x40, 0x7f, 0x40, 0x40}, // T
  {0x7e, 0x01, 0x01, 0x01, 0x7e}, // U
  {0x7c, 0x02, 0x01, 0x02, 0x7c}, // V
  {0x7f, 0x02, 0x04, 0x02, 0x7f}, // W 
  {0x63, 0x14, 0x08, 0x14, 0x63}, // X
  {0x60, 0x10, 0x0f, 0x10, 0x60}, // Y
  {0x43, 0x45, 0x49, 0x51, 0x61}, // Z
  {0x00, 0x7f, 0x41, 0x00, 0x00}, // [
  {0x20, 0x10, 0x0c, 0x02, 0x01}, // \
  {0x00, 0x41, 0x7f, 0x00, 0x00}, // [
  {0x08, 0x30, 0x40, 0x30, 0x08}, // ^
  {0x01, 0x01, 0x01, 0x01, 0x01}, // _
  {0x01, 0x40, 0x20, 0x00, 0x00}, // `
  {0x3f, 0x48, 0x48, 0x48, 0x3f}, // A
  {0x7f, 0x49, 0x49, 0x49, 0x36}, // B
  {0x3e, 0x41, 0x41, 0x41, 0x22}, // C
  {0x7f, 0x41, 0x41, 0x22, 0x1c}, // D
  {0x7f, 0x49, 0x49, 0x49, 0x41}, // E
  {0x7f, 0x48, 0x48, 0x48, 0x40}, // F
  {0x3e, 0x41, 0x49, 0x49, 0x2e}, // G
  {0x7f, 0x08, 0x08, 0x08, 0x7f}, // H
  {0x00, 0x41, 0x7f, 0x41, 0x00}, // I
  {0x06, 0x01, 0x01, 0x01, 0x7e}, // J
  {0x7f, 0x08, 0x14, 0x22, 0x41}, // K
  {0x7f, 0x01, 0x01, 0x01, 0x01}, // L
  {0x7f, 0x20, 0x10, 0x20, 0x7f}, // M
  {0x7f, 0x10, 0x08, 0x04, 0x7f}, // N
  {0x3e, 0x41, 0x41, 0x41, 0x3e}, // O
  {0x7f, 0x48, 0x48, 0x48, 0x30}, // P
  {0x3e, 0x41, 0x45, 0x42, 0x3d}, // Q
  {0x7f, 0x48, 0x4c, 0x4a, 0x31}, // R
  {0x31, 0x49, 0x49, 0x49, 0x46}, // S
  {0x40, 0x40, 0x7f, 0x40, 0x40}, // T
  {0x7e, 0x01, 0x01, 0x01, 0x7e}, // U
  {0x7c, 0x02, 0x01, 0x02, 0x7c}, // V
  {0x7f, 0x02, 0x04, 0x02, 0x7f}, // W 
  {0x63, 0x14, 0x08, 0x14, 0x63}, // X
  {0x60, 0x10, 0x0f, 0x10, 0x60}, // Y
  {0x43, 0x45, 0x49, 0x51, 0x61}, // Z
  {0x08, 0x08, 0x36, 0x41, 0x41}, // {
  {0x00, 0x00, 0x7f, 0x00, 0x00}, // |
  {0x41, 0x41, 0x36, 0x08, 0x08}, // }
  {0x10, 0x20, 0x10, 0x10, 0x20}  // ~
};

// Get an index into the current font corresponding to the 
// @letter    ASCII character to convert
// @return    index into the current font corresponding to the letter,
//            or 255 if not found.
unsigned char fontGetAsciiChar(char letter)
{
  if (letter >= 32 && letter <= 126) {
    // one of the ascii chars we represent
    return letter - 31;
  }
  else {
    // we don't have a character for that, sorry!
    return 0; // display unicode block thing
  }
}

//////////////////////////////////////////////////////////////////////////////
// Display driver section
//////////////////////////////////////////////////////////////////////////////

#define SINGLE_BUFFER 1    // Single buffered mode
#define DOUBLE_BUFFER 2    // Double buffered mode

// Set this to DOUBLE_ BUFFER to enable double-buffered display,
// or SINGLE_BUFFER to save memory.
#define MAX_DISPLAY_MODE DOUBLE_BUFFER

#define DISPLAY_ROWS 7          // Number of rows in the display
#define DISPLAY_COLS_B 10       // Number of 8-bit columns in the display
#define DISPLAY_COLORS 2        // Number of colors in the display (must be 2)

char displayMode;   // Current display mode, either SINGLE_BUFFER or DOUBLE_BUFFER

// 80x7 bi-color video buffer
// green is arrays 0-6, red is 7-13
// Not a 2d array because then we couldn't point to it.
unsigned char videoBuffer[MAX_DISPLAY_MODE][DISPLAY_ROWS * DISPLAY_COLORS * DISPLAY_COLS_B];


unsigned char* displayBuffer;    // Buffer that is currently being displayed
unsigned char* workBuffer;       // Buffer that is currently being drawn to.
                                 // Note that for single-buffered systems,
                                 // this might be the same as displayBuffer


int videoCurrentRow;        // Row that is currently being drawn
int videoCurrentCol;        // Column that is currently being drawn
boolean videoFlipPage;      // Flag to indicate that the video buffers
                            // should be swapped after the current screen
                            // draw is finished


// This function is called when the SPI finishes transferring a byte of data.
ISR(SPI_STC_vect)
{
  // Determine if there is more data to transfer in this row; otherwise, turn
  // the row on and start a timer.
  if (videoCurrentCol < DISPLAY_COLS_B * 2)
  {
    // Just transfer the next byte.  Note that we have to interleve green and
    // red color banks.
    if (videoCurrentCol & 1) {  
      SPDR = displayBuffer[(videoCurrentRow+7)*DISPLAY_COLS_B + 9-(videoCurrentCol/2)];
    }
    else {
      SPDR = displayBuffer[videoCurrentRow*DISPLAY_COLS_B + 9-(videoCurrentCol/2)];
    }
    
    videoCurrentCol += 1;
  }
  else
  {
    // Turn on the row line, then start the timer.  The timer ISR is then
    // expected to turn off the row and start the next column transmission.

    // Turn on the row
    digitalWrite(rowPins[videoCurrentRow], HIGH);
    
    // Start the timer
    TCCR2B = (1<<CS22)|(0<<CS21)|(0<<CS20);
  }
}

// This function is called when timer2 overflows
ISR(TIMER2_OVF_vect)
{
  // Turn off the timer (disable it's clock source)
  TCCR2B = 0;
  
  // Turn off the current row
  digitalWrite(rowPins[videoCurrentRow], LOW);

  // Advance the row count
  videoCurrentRow++;
  if (videoCurrentRow >= DISPLAY_ROWS)
  {
    videoCurrentRow = 0;
    
    // If the page should be flipped, do it here.
    if (videoFlipPage && displayMode == DOUBLE_BUFFER)
    {
      videoFlipPage = false;
      
      unsigned char* temp = displayBuffer;
      displayBuffer = workBuffer;
      workBuffer = temp;
    }
  }

  // Reset the column count
  videoCurrentCol = 0;

  // Drop out nothing to start the next column display loop
  SPDR = 0;
}


// Flip the front and back buffers
// @blocking    If true, wait until page has flipped before returning.
void flipVideoBuffer(bool blocking = true)
{
  if (displayMode == DOUBLE_BUFFER)
  {
    // Just set the flip flag, the buffer will flip between redraws
    videoFlipPage = true;
  
    // If we are blocking, sit here until the page flips.
    while (blocking && videoFlipPage) {
      delay(1);
    }
  }
}


// Clear the working video buffer
void clearVideoBuffer()
{
   memset(workBuffer, 0, DISPLAY_ROWS * DISPLAY_COLS_B * DISPLAY_COLORS);
}


// Set up the video buffering mode
// @mode    either SINGLE_BUFFER or DOUBLE_BUFFER
void setupVideoBuffer(int mode)
{
  byte clr;    // Dummy variable, used to clear garbage from SPI registers

  // Only set double buffering if there is memory allocated for it
  if (mode == DOUBLE_BUFFER && MAX_DISPLAY_MODE >= DOUBLE_BUFFER) {
    displayMode = DOUBLE_BUFFER;
  }
  else {
    displayMode = SINGLE_BUFFER;
  }
  
  // Configure I/O pins for SPI port
  pinMode(DATAOUT, OUTPUT);
  pinMode(DATAIN, INPUT);
  pinMode(SPICLOCK,OUTPUT);
  
  // TODO: Pin 10 interferes with the SPI port.  Why?
  pinMode(10, OUTPUT);
  digitalWrite(10, LOW);
  
  // Configure SPI port
  
  // SPCR = 11010000
  //interrupt enabled,spi enabled,msb 1st,master,clk low when idle,
  //sample on leading edge of clk,system clock/4 (fastest)
  SPCR = (1<<SPIE)|(1<<SPE)|(1<<MSTR);
  clr=SPSR;
  clr=SPDR;
  delay(10);
  
  // Set up Timer 2 to generate interrupts on overflow (don't start it, though)
  TCCR2A = 0;
  TCCR2B = 0;
  TIMSK2 = (1<<TOIE2);
  
  // Set up row select lines
  for (int i = 0; i < sizeof(rowPins); i++)
  {
    pinMode(rowPins[i], OUTPUT);
    digitalWrite(rowPins[i], LOW);
  }

  // Configure the display buffer pointers
  displayBuffer = videoBuffer[0];
  if (displayMode == SINGLE_BUFFER) {
    workBuffer = displayBuffer;
  }
  else {
    workBuffer = videoBuffer[1];
  }
  
  // Clear a buffer, then display it.
  clearVideoBuffer();
  flipVideoBuffer(false);

  // Jump start the display by writing to the SPI
  videoCurrentRow = 0;
  videoCurrentCol = 0;
  SPDR = 0x0;
}


// Draw a letter at any point in the display buffer
// @letter  in ASCII
// @offset  Column offset to draw the character
// @color   String color (0 = green, 1 = red, 2 = yellow)
void drawChar(char letter, int offset, unsigned char color)
{ 
  // Don't bother trying to draw if we are off the screen
  if (offset <= -fontWidth) {
    return;
  }
  
  // Convert the ASCII letter to a font offset
  unsigned char fontOffset = fontGetAsciiChar(letter);
  
  // If the character isn't available, don't draw it
  // TODO: draw a rectangle, a la unicode?
  if (fontOffset == FONT_BAD_CHARACTER) {
    return;
  }
  
  // Re-map the color into a bitfield (a hack!)
  color += 1;
  
  // Calculate which byte the character starts on, and the bit offset from
  // that byte
  int alignedCol = offset/8;
  int alignedOffset = offset%8;
    
  for (int col = 0; col < fontWidth; col++)
  {
    // If the current column is actually on the screen, draw it
    if (alignedCol >= 0 && alignedOffset >= 0 && alignedCol < DISPLAY_COLS_B)
    {
      if( color & 0x1) {          
        for (int row = 0; row < DISPLAY_ROWS; row++) {
          workBuffer[row*DISPLAY_COLS_B + alignedCol] |=
                    ((font[fontOffset][col] >> row) & 0x1) << alignedOffset;
        }
      }
      if( color & 0x2) {
       for (int row = 0; row < DISPLAY_ROWS; row++) {
          workBuffer[(row + DISPLAY_ROWS)*DISPLAY_COLS_B + alignedCol] |=
                    ((font[fontOffset][col] >> row) & 0x1) << alignedOffset;
       }
      }
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


// Draw a string at any point into the buffer
// @string  C-style string
// @length  length of said string
// @offset  column offset to display string
// @color   String color (0 = green, 1 = red, 2 = yellow)
// @spacing Amount of space between characters
void drawString(char* string, char length, int offset,
                unsigned char color, unsigned int spacing = 1)
{
  for (int i = 0; i < length; i++) {
    drawChar(string[i], offset, color);
    offset += fontWidth + spacing;
  }
} 


// Draw a pixel on the working buffer
// @color   Pixel color (0 = green, 1 = red, 2 = yellow)
void drawPixel(unsigned char row, unsigned char offset, unsigned char color)
{
  // Re-map the color into a bitfield (a hack!)
  color += 1;  

  // Calculate which byte the pixel occupies, and the bit offset from
  // that byte
  int alignedCol = offset/8;
  int alignedOffset = offset%8;

  if( color & 0x1)
  {
    workBuffer[row*DISPLAY_COLS_B + alignedCol] |= 1 << alignedOffset;
  }
  if( color & 0x2)
  {
    workBuffer[(row + DISPLAY_ROWS)*DISPLAY_COLS_B + alignedCol] |=
              1 << alignedOffset;
  }
}


//////////////////////////////////////////////////////////////////////////////
// Application
//////////////////////////////////////////////////////////////////////////////

#define USER_STRING_MAX_LENGTH 100    // Maximum length of a user message


char userStringInput[USER_STRING_MAX_LENGTH];
char userStringInputLen;

char userString[USER_STRING_MAX_LENGTH];
char userStringLen;

int scrollPosition;

prog_uchar startMessage[] PROGMEM = "HackPGH";


// Program setup
void setup()
{
  // Set up LED display, use double buffering if possible
  setupVideoBuffer(DOUBLE_BUFFER);
  
  // Open the serial port at 9600 baud
  Serial.begin(9600);

  // Copy in a welcome message
  for (int i = 0; i < sizeof(startMessage); i++) {
    userString[i] = startMessage[i];
  }
  
  userStringLen = sizeof(startMessage);
  scrollPosition = DISPLAY_COLS_B*8;    // Start at the end of the string

  userStringInputLen = 0;
}


// Main loop
void loop()
{
  // Look for new serial input
  if (Serial.available() > 0)
  {
    userStringInput[userStringInputLen] = Serial.read();
//    Serial.print(userStringInput[userStringInputLen]);

    // If we get the end character, copy over the message and begin displaying it
    if (userStringInput[userStringInputLen] == '?' && userStringInputLen > 0)
    {   
      // Record the length information
      userStringLen = userStringInputLen;
      userStringInputLen = 0;
      scrollPosition = DISPLAY_COLS_B*8;
      
      // then copy over the message
      memcpy ( userString, userStringInput, userStringLen );
    }
    else {
      userStringInputLen++;
    }
  }
  
  // Draw the next frame and wait a bit
  clearVideoBuffer();
  drawString(userString, userStringLen, scrollPosition, 0);
  flipVideoBuffer();
  delay(40);
  
  // Then update the scroll position
  scrollPosition--;
  if (scrollPosition < -userStringLen*8) {
    scrollPosition = DISPLAY_COLS_B*8;
  }
}

  
#if 0
  for (int j = 0; j < 2; j++) {
    // Text bounce demo
    for (int i = -8; i < 24; i++) {
      clearVideoBuffer();
      drawString("HackPGH", 7, 0+i, 0);
      drawString("FTW", 3, 48+i, 2);
    
      flipVideoBuffer();
      delay(120);
    }

    for (int i = 22; i > -8; i--) {
      clearVideoBuffer();
      drawString("HackPGH", 7, 0+i, 1);
      drawString("FTW", 3, 48+i, 2);
    
      flipVideoBuffer();
      delay(120);
    }
  }
#endif
