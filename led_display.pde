#include <avr/pgmspace.h>

// Sketch to drive a hacked 80x7 2-color LED display
// By Matt Mets and Marty McGuire

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

// I/O pins that control the row select lines
unsigned char rowPins[] = {2, 3, 4, 5, 6, 7, 8};

// Serial pins that control the column display
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

#define FONT_COUNT 96
#define FONT_WIDTH 5

// Not a 2d array because the PROGMEM macro can't handle them
prog_uchar font[FONT_COUNT * FONT_WIDTH] PROGMEM = {
  0x7f, 0x41, 0x41, 0x41, 0x7f, // fail char (unicode block)
  0x00, 0x00, 0x00, 0x00, 0x00, // space
  0x00, 0x00, 0x7d, 0x00, 0x00, // !
  0x00, 0x60, 0x00, 0x60, 0x00, // "
  0x14, 0x7f, 0X14, 0X7f, 0x14, // #
  0x14, 0x2a, 0x7f, 0x2a, 0x14, // $
  0x62, 0x64, 0x08, 0x13, 0x23, // %
  0x36, 0x49, 0x35, 0x02, 0x05, // &
  0x00, 0x00, 0x60, 0x00, 0x00, // '
  0x00, 0x1c, 0x22, 0x41, 0x00, // (
  0x00, 0x41, 0x22, 0x1c, 0x00, // )
  0x2a, 0x1c, 0x7f, 0x1c, 0x2a, // *
  0x00, 0x08, 0x1c, 0x08, 0x00, // +
  0x00, 0x0d, 0x0e, 0x00, 0x00, // ,
  0x04, 0x04, 0x04, 0x04, 0x04, // -
  0x00, 0x03, 0x03, 0x00, 0x00, // .
  0x01, 0x02, 0x0c, 0x10, 0x20, // /
  0x3e, 0x45, 0x49, 0x51, 0x3e, // 0
  0x00, 0x10, 0x20, 0x7f, 0x00, // 1
  0x47, 0x49, 0x49, 0x49, 0x31, // 2
  0x42, 0x49, 0x59, 0x69, 0x46, // 3
  0x08, 0x18, 0x28, 0x7f, 0x08, // 4
  0x71, 0x49, 0x49, 0x49, 0x46, // 5
  0x3e, 0x49, 0x49, 0x49, 0x06, // 6
  0x40, 0x47, 0x48, 0x50, 0x60, // 7
  0x36, 0x49, 0x49, 0x49, 0x36, // 8
  0x30, 0x49, 0x49, 0x49, 0x3e, // 9
  0x00, 0x36, 0x36, 0x00, 0x00, // :
  0x00, 0x37, 0x36, 0x00, 0x00, // ;
  0x08, 0x14, 0x14, 0x22, 0x22, // <
  0x14, 0x14, 0x14, 0x14, 0x14, // =
  0x22, 0x22, 0x14, 0x14, 0x08, // >
  0x20, 0x40, 0x4d, 0x48, 0x38, // ?
  0x3e, 0x41, 0x5d, 0x55, 0x1f, // @
  0x3f, 0x48, 0x48, 0x48, 0x3f, // A
  0x7f, 0x49, 0x49, 0x49, 0x36, // B
  0x3e, 0x41, 0x41, 0x41, 0x22, // C
  0x7f, 0x41, 0x41, 0x22, 0x1c, // D
  0x7f, 0x49, 0x49, 0x49, 0x41, // E
  0x7f, 0x48, 0x48, 0x48, 0x40, // F
  0x3e, 0x41, 0x49, 0x49, 0x2e, // G
  0x7f, 0x08, 0x08, 0x08, 0x7f, // H
  0x00, 0x41, 0x7f, 0x41, 0x00, // I
  0x06, 0x01, 0x01, 0x01, 0x7e, // J
  0x7f, 0x08, 0x14, 0x22, 0x41, // K
  0x7f, 0x01, 0x01, 0x01, 0x01, // L
  0x7f, 0x20, 0x10, 0x20, 0x7f, // M
  0x7f, 0x10, 0x08, 0x04, 0x7f, // N
  0x3e, 0x41, 0x41, 0x41, 0x3e, // O
  0x7f, 0x48, 0x48, 0x48, 0x30, // P
  0x3e, 0x41, 0x45, 0x42, 0x3d, // Q
  0x7f, 0x48, 0x4c, 0x4a, 0x31, // R
  0x31, 0x49, 0x49, 0x49, 0x46, // S
  0x40, 0x40, 0x7f, 0x40, 0x40, // T
  0x7e, 0x01, 0x01, 0x01, 0x7e, // U
  0x7c, 0x02, 0x01, 0x02, 0x7c, // V
  0x7f, 0x02, 0x04, 0x02, 0x7f, // W 
  0x63, 0x14, 0x08, 0x14, 0x63, // X
  0x60, 0x10, 0x0f, 0x10, 0x60, // Y
  0x43, 0x45, 0x49, 0x51, 0x61, // Z
  0x00, 0x7f, 0x41, 0x00, 0x00, // [
  0x20, 0x10, 0x0c, 0x02, 0x01, // \
  0xff, 0xff, 0xff, 0xff, 0xff,            ///TODO: Explain why this is necessary
  0x00, 0x41, 0x7f, 0x00, 0x00, // ]
  0x08, 0x30, 0x40, 0x30, 0x08, // ^
  0x01, 0x01, 0x01, 0x01, 0x01, // _
  0x00, 0x40, 0x20, 0x00, 0x00, // `
  0x3f, 0x48, 0x48, 0x48, 0x3f, // a
  0x7f, 0x49, 0x49, 0x49, 0x36, // b
  0x3e, 0x41, 0x41, 0x41, 0x22, // c
  0x7f, 0x41, 0x41, 0x22, 0x1c, // d
  0x7f, 0x49, 0x49, 0x49, 0x41, // e
  0x7f, 0x48, 0x48, 0x48, 0x40, // f
  0x3e, 0x41, 0x49, 0x49, 0x2e, // g
  0x7f, 0x08, 0x08, 0x08, 0x7f, // h
  0x00, 0x41, 0x7f, 0x41, 0x00, // i
  0x06, 0x01, 0x01, 0x01, 0x7e, // j
  0x7f, 0x08, 0x14, 0x22, 0x41, // k
  0x7f, 0x01, 0x01, 0x01, 0x01, // l
  0x7f, 0x20, 0x10, 0x20, 0x7f, // m
  0x7f, 0x10, 0x08, 0x04, 0x7f, // n
  0x3e, 0x41, 0x41, 0x41, 0x3e, // o
  0x7f, 0x48, 0x48, 0x48, 0x30, // p
  0x3e, 0x41, 0x45, 0x42, 0x3d, // q
  0x7f, 0x48, 0x4c, 0x4a, 0x31, // r
  0x31, 0x49, 0x49, 0x49, 0x46, // s
  0x40, 0x40, 0x7f, 0x40, 0x40, // t
  0x7e, 0x01, 0x01, 0x01, 0x7e, // u
  0x7c, 0x02, 0x01, 0x02, 0x7c, // v
  0x7f, 0x02, 0x04, 0x02, 0x7f, // w 
  0x63, 0x14, 0x08, 0x14, 0x63, // x
  0x60, 0x10, 0x0f, 0x10, 0x60, // y
  0x43, 0x45, 0x49, 0x51, 0x61, // z
  0x08, 0x08, 0x36, 0x41, 0x41, // {
  0x00, 0x00, 0x7f, 0x00, 0x00, // |
  0x41, 0x41, 0x36, 0x08, 0x08, // }
  0x0C, 0x10, 0x0C, 0x04, 0x18  // ~
};


// Get an index into the current font corresponding to the 
// @letter    ASCII character to convert
// @return    index into the current font corresponding to the letter,
//            or 255 if not found.
unsigned char fontGetAsciiChar(unsigned char letter)
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

// In-line text modifiers
#define FOREGROUND_COLOR 0x1C  // Set the foreground color.  Color determined
                               // by the following byte:
                               //   0=black, 1=green, 2=red, 3=yellow
#define BACKGROUND_COLOR 0x1D  // Set the background color.  Color determined
                               // by the following byte:
                               //   0=black, 1=green, 2=red, 3=yellow
#define BLINK 0x1E             // Control blink tag.  0=off, 1=on


#define BLINK_ON '1'
#define BLINK_OFF '0'



// Internal color bitfields.  Pass these to functions
#define COLOR_BLACK 0                          // Black
#define COLOR_GREEN 1                          // Green
#define COLOR_RED 2                            // Red
#define COLOR_YELLOW (COLOR_GREEN | COLOR_RED) // Yellow



#define SINGLE_BUFFER 1    // Single buffered mode
#define DOUBLE_BUFFER 2    // Double buffered mode

// Set this to DOUBLE_ BUFFER to enable double-buffered display,
// or SINGLE_BUFFER to save memory.
#define MAX_DISPLAY_MODE DOUBLE_BUFFER

#define DISPLAY_ROWS 7          // Number of rows in the display
#define DISPLAY_COLS_B 10       // Number of 8-bit columns in the display
#define DISPLAY_COLORS 2        // Number of colors in the display (must be 2)

unsigned char displayMode;   // Current display mode, either SINGLE_BUFFER or DOUBLE_BUFFER

// 80x7 bi-color video buffer
// green is arrays 0-6, red is 7-13
// Individual buffers are not 2d arrays because then we couldn't point to them
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
      SPDR = displayBuffer
               [(videoCurrentRow+7)*DISPLAY_COLS_B + 9-(videoCurrentCol/2)];
    }
    else {
      SPDR = displayBuffer
               [videoCurrentRow*DISPLAY_COLS_B + 9-(videoCurrentCol/2)];
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

  // Wait a bit for the current row to turn off (no joke!)
  // This prevents a faint ghost signal as the column data is shifted out.
  // For extra speed, make this a second call to the interrupt.
  for (unsigned int timer_2_scratch = 0; timer_2_scratch < 70; timer_2_scratch++) {};

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


// Clear the working video buffer, optionally filling it with a color
// @backColor  Color to fill the screen with (defaults to black)
void clearVideoBuffer(unsigned char backColor = COLOR_BLACK)
{ 
  if (backColor & COLOR_GREEN) {  
    memset(workBuffer, 0xFF, DISPLAY_ROWS * DISPLAY_COLS_B);
  }
  else {
    memset(workBuffer, 0, DISPLAY_ROWS * DISPLAY_COLS_B);
  }
  
  if (backColor & COLOR_RED) {  
    memset(workBuffer + DISPLAY_ROWS * DISPLAY_COLS_B, 0xFF, DISPLAY_ROWS * DISPLAY_COLS_B);
  }
  else {
    memset(workBuffer + DISPLAY_ROWS * DISPLAY_COLS_B, 0, DISPLAY_ROWS * DISPLAY_COLS_B);
  }
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
// @letter    in ASCII
// @offset    Column offset to draw the character
// @color     Foreground color
void drawChar(unsigned char letter,
              int offset,
              unsigned char color)
{ 
  // Don't bother trying to draw if we are off the screen
  if (offset <= -FONT_WIDTH) {
    return;
  }

  // Convert the ASCII letter to a font offset
  unsigned char fontOffset = fontGetAsciiChar(letter);

  // If the character isn't available, don't draw it
  // TODO: draw a rectangle, a la unicode?
  if (fontOffset == FONT_BAD_CHARACTER) {
    return;
  }

  // Calculate which byte the character starts on, and the bit offset from
  // that byte
  int alignedCol = offset/8;
  int alignedOffset = offset%8;
   
  for (int col = 0; col < FONT_WIDTH; col++)
  {
    // If the current column is actually on the screen, draw it
    if (alignedCol >= 0 && alignedOffset >= 0 && alignedCol < DISPLAY_COLS_B)
    {
      // Look up the character
      unsigned char font_data = pgm_read_byte_near(font + fontOffset*FONT_WIDTH + col);

      // Then draw it row by row, because the font is stored that way
      for (int row = 0; row < DISPLAY_ROWS; row++) {
        // Precompute bit position and 
        unsigned char newBit = ((font_data >> row) & 0x1) << alignedOffset;
        unsigned char bufferOffset = row*DISPLAY_COLS_B + alignedCol;
        
        if (color & COLOR_GREEN) {
          workBuffer[bufferOffset] |= newBit;
        }
        else {
          workBuffer[bufferOffset] &= ~newBit;
        }
        
        if (color & COLOR_RED) {
          workBuffer[bufferOffset + DISPLAY_ROWS*DISPLAY_COLS_B] |= newBit;
        }
        else {
          workBuffer[bufferOffset + DISPLAY_ROWS*DISPLAY_COLS_B] &= ~newBit;
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
// @string    C-style string, with optional in-line modifier strings:
//            Foreground color: 0x1C [color]
//            Background color: 0x1d [color]
// @length    length of said string
// @offset    column offset to display string
// @color     Starting color (can be modified by inline modifiers)
// @spacing   Amount of space between characters
void drawString(unsigned char* string,
                unsigned char length,
                int offset,
                unsigned char color = COLOR_GREEN,
                unsigned int spacing = 1)
{
  // blink Phase, note that this only works if drawString is only called once per display...
  static unsigned char blinkPhase;

  blinkPhase = (blinkPhase + 1) % 4;

  boolean blinkMode = false;
    
  for (int i = 0; i < length; i++) {
    if (string[i] == FOREGROUND_COLOR) {
      if (i + 1 < length) {
        // Re-map the color into a bitfield
        switch (string[i+1]) {
          case '0':    color=COLOR_BLACK;   break;
          case '1':    color=COLOR_GREEN;   break;
          case '2':    color=COLOR_RED;     break;
          case '3':    color=COLOR_YELLOW;  break;
        }
        i++;
      }
    }
    else if (string[i] == BLINK) {
      // Turn the blink tag on or off
      if (i + 1 < length) {
        switch (string[i+1]) {
          case BLINK_ON:  blinkMode = true;  break;
          case BLINK_OFF: blinkMode = false; break;
        }
        i++;
      }
    }
    else if (string[i] == BACKGROUND_COLOR) {
      // Don't deal with background colors here, only in processString()
      if (i + 1 < length) {
        i++;
      }
    }
    else {
      // Finally, if we are in the right 
      if (!(blinkMode && blinkPhase < 2)) {
        drawChar(string[i], offset, color);
      }
      
      offset += FONT_WIDTH + spacing;
    }
  }
} 


// Determine the display length and background color of a string
// @string    C-style string, with optional in-line modifier strings:
//            Foreground color: 0x1C_, where _ is a color
//            Background color: 0x1d_, where _ is a color
//            Blink: 0x1e_, where _ is 1 for on, 0 for off
//            
// @length    length of said string
// [output] @displayLength  Display length = total length - nonprinting characters
// [output] @backColor Background color (last one in string)
void processString(unsigned char* string,
                   unsigned char length,
                   unsigned char& displayLength,
                   unsigned char& backColor)
{
  displayLength = length;
    
  for (int i = 0; i < length; i++) {
    if ((string[i] == FOREGROUND_COLOR) || (string[i] == BLINK)) {
      // Skip over foreground color and blink tags, but subtract their lengths
      displayLength--;
      
      if (i + 1 < length) {      
        displayLength--;
        i++;
      }
    }
    else if (string[i] == BACKGROUND_COLOR) {
      // Record background color, overwriting any previous ones
      displayLength--;
      
      if (i + 1 < length) {
        displayLength--;      
        switch (string[i+1]) {
          case '0':    backColor=COLOR_BLACK;   break;
          case '1':    backColor=COLOR_GREEN;   break;
          case '2':    backColor=COLOR_RED;     break;
          case '3':    backColor=COLOR_YELLOW;  break;
        }

        i++;
      }

    }
  }
}


// Draw a pixel on the working buffer (untested!)
// @row     Pixel row, from top
// @offset  Pixel column, from left
// @color   Pixel color
void drawPixel(unsigned char row, unsigned char offset, unsigned char color)
{
  // Calculate which byte the pixel occupies, and the bit offset from
  // that byte
  int alignedCol = offset/8;
  int alignedOffset = offset%8;

  if (color & COLOR_GREEN)
  {
    workBuffer[row*DISPLAY_COLS_B + alignedCol] |= 1 << alignedOffset;
  }
  if (color & COLOR_RED)
  {
    workBuffer[(row + DISPLAY_ROWS)*DISPLAY_COLS_B + alignedCol] |=
              1 << alignedOffset;
  }
}


//////////////////////////////////////////////////////////////////////////////
// Application
//////////////////////////////////////////////////////////////////////////////

#define USER_STRING_MAX_LENGTH 200    // Maximum length of a user message

// Input buffer, unfinished user input goes here
unsigned char userStringInput[USER_STRING_MAX_LENGTH];
unsigned char userStringInputLen;

// Display buffer, currently being drawn
unsigned char userString[USER_STRING_MAX_LENGTH];
unsigned char userStringLen;
unsigned char userStringDisplayLen;

// Current 
unsigned char backColor;

int scrollPosition;

// Default message
prog_uchar startMessage[] PROGMEM =
  "\x1d" "0"                      // background color = black
  "\x1c" "3" "Welcome to "        // text color = yellow, text "Welcome to"
  "\x1c" "1" "Hack Pittsburgh  "  // text color = green, text "Hack Pittsburgh"
  "\x1c" "2" "Sign of "           // text color = red, text "Sign of"
  "\x1e" "1"                      // blink on
  "doom "                         // text "doom"
  "\x1e" "0"                      // blink off
  "!!!!!!!1011";                  // text "doom"


// Program setup
void setup()
{
  // Set up LED display, use double buffering if possible
  setupVideoBuffer(DOUBLE_BUFFER);
  
  // Open the serial port at 9600 baud
  Serial.begin(9600);

  // Copy in a welcome message
  for (int i = 0; i < sizeof(startMessage) - 1; i++) {
    userString[i] = pgm_read_byte_near(startMessage + i);
  }
  
  userStringLen = sizeof(startMessage) - 1;  // Ignore the null zero
  scrollPosition = DISPLAY_COLS_B*8;         // Start at the end of the screen

  // Process the welcome message to determine length and background color
  processString(userString, userStringLen, userStringDisplayLen, backColor);

  // And clear the input buffer for the first message
  userStringInputLen = 0;
}


// Main loop
void loop()
{
  // Look for new serial input
  if (Serial.available() > 0)
  {
    unsigned char new_data = Serial.read();
//    Serial.print(new_data);

    // If we got a new line signal, see if there is a message
    if (new_data == '\n' || new_data == '\r') {
      // Only proceed if there is actually data
      if (userStringInputLen > 0) {
        // Record the length information
        userStringLen = userStringInputLen;
        userStringInputLen = 0;
      
        // then copy over the message
        memcpy ( userString, userStringInput, userStringLen );
        
        // Determine the display length (total length minus inline control characters)
        // and background color of the string
        processString( userString, userStringLen,
                       userStringDisplayLen, backColor );
        
        // Finally, set the text to scroll in from the end
        scrollPosition = DISPLAY_COLS_B*8;
      }
    }
    // Handle backspace
    else if (new_data == '\x08') {
      if (userStringInputLen > 0) {
        userStringInputLen--;
      }
    }
    else if (userStringInputLen < USER_STRING_MAX_LENGTH)
    {
      // Add the new character to the message and increment
      userStringInput[userStringInputLen] = new_data;
      userStringInputLen++;
    }
  }
  
  // Draw the next frame and wait a bit
  clearVideoBuffer(backColor);
  drawString(userString, userStringLen, scrollPosition);
  flipVideoBuffer();
  delay(40);
  
  // Then update the scroll position
  scrollPosition--;
  if (scrollPosition < -userStringDisplayLen*6) {
    scrollPosition = DISPLAY_COLS_B*8;
  }
}
