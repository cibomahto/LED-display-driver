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

#define FONT_BAD_CHARACTER 255

// 0-25: letters
// 26-36: numbers, style A
// 37-47: numbers, style B
const int fontCount = 46;
const int fontWidth = 5;
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
    return FONT_BAD_CHARACTER;
  }
}


#define SINGLE_BUFFER 0
#define DOUBLE_BUFFER 1

char displayMode;   // Either SINGLE_BUFFER or DOUBLE_BUFFER

#define ROWS 7      // Note that there is a set of rows for each color, so 14 in total
#define COLS 10

// Double 80x7 bi-color video buffer
// green is arrays 0-6, red is 7-13
// Not a 2d array because then we couldn't point to it.
unsigned char videoBuffer[2][ROWS*2 * COLS];

// Display buffer is the one we are displaying.  Working buffer is the one we are assembling.
unsigned char* displayBuffer;
unsigned char* workBuffer;


// 7 pins that turn on the rows
unsigned char rowPins[] = {2, 3, 4, 5, 6, 7, 8};

// Colored stripes
unsigned char testPatternB[] = {0xb6, 0x6d, 0xdb, 0xb6, 0x6d, 0xdb, 0xb6, 0x6d, 0xdb, 0xb6,
                                0x6d, 0xdb, 0xb6, 0x6d, 0xdb, 0xb6, 0x6d, 0xdb, 0xb6, 0x6d,
                                0xdb, 0xb6, 0x6d, 0xdb, 0xb6, 0x6d, 0xdb, 0xb6, 0x6d};

#define DATAOUT 11      //MOSI
#define DATAIN 12       //MISO - not used, but part of builtin SPI
#define SPICLOCK  13    //SCK


int videoCurrentRow;
int videoCurrentCol;
boolean videoFlipPage;


#define USER_STRING_MAX_LENGTH 100
char userStringInput[USER_STRING_MAX_LENGTH];
char userStringInputLen;

char userString[USER_STRING_MAX_LENGTH];
char userStringLen;

int scrollPosition;

char startMessage[] = "HackPGH";

// This function is called whenever the SPI is finished transferring a byte of data.
ISR(SPI_STC_vect)
{
  // Determine if there is more data to transfer in this row; otherwise, turn the row on
  // and start a timer.
  if (videoCurrentCol < COLS * 2) {
    // Just transfer the next byte.  Note that we have to interleve green and red banks.
    if (videoCurrentCol & 1) {  
      SPDR = displayBuffer[(videoCurrentRow+7)*COLS + 9-(videoCurrentCol/2)];
    }
    else {
      SPDR = displayBuffer[videoCurrentRow*COLS + 9-(videoCurrentCol/2)];
    }
    
    videoCurrentCol += 1;
  }
  else {
    // Turn on the row line, then start the timer.  The timer ISR is then expected to
    // turn off the row and start the next column transmission.

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
  if (videoCurrentRow >= ROWS) {
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
  if (displayMode == DOUBLE_BUFFER) {
    // Just set the flip flag, the buffer will flip between redraws
    videoFlipPage = true;
  
    // If we are blocking, sit here until the page flips.
    while (blocking && videoFlipPage) {
      delay(1);
    }
  }
}


// Clear the video buffer
// if we are in double-buffer mode, clear the back buffer, otherwise clear the front
void clearVideoBuffer()
{
  for (int i = 0; i < 14; i++) {
    for (int j = 0; j < 10; j++) {
      workBuffer[i*COLS + j] = 0;
    }
  }
}


// Set up the video buffering mode
// @mode    either SINGLE_BUFFER or DOUBLE_BUFFER
void setupVideoBuffer(int mode)
{
  if (mode == DOUBLE_BUFFER) {
    displayMode = DOUBLE_BUFFER;
  }
  else {
    displayMode = SINGLE_BUFFER;
  }
  
  byte clr;
  pinMode(DATAOUT, OUTPUT);
  pinMode(DATAIN, INPUT);
  pinMode(SPICLOCK,OUTPUT);
  
  pinMode(10, OUTPUT);
  digitalWrite(10, LOW);
  
  // Set up SPI port
  
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
  for (int i = 0; i < sizeof(rowPins); i++) {
    pinMode(rowPins[i], OUTPUT);
    digitalWrite(rowPins[i], LOW);
  }

  displayBuffer = videoBuffer[0];
  if (displayMode == SINGLE_BUFFER) {
    workBuffer = displayBuffer;
  }
  else {
    workBuffer = videoBuffer[1];
  }
  
  // Clear the front buffer
  clearVideoBuffer();
  flipVideoBuffer(false);

  // Jump start the display by writing to the SPI
  videoCurrentRow = 0;
  videoCurrentCol = 0;
  SPDR = 0x55;
}


// Draw a letter at any point in the display buffer
// @letter  in ASCII
// @offset  in leds from the origin
// @color   String color (0 = green, 1 = red, 2 = yellow)
void drawChar(char letter, int offset, unsigned char color)
{
  // Don't bother trying to draw if we are off the screen
  if (offset <= -fontWidth) {
    return;
  }
  
  // Convert the ASCII letter to a font offset
  unsigned char fontOffset = fontGetAsciiChar(letter);
  if (fontOffset == FONT_BAD_CHARACTER) { return; }
  
  // Re-map the color into a bitfield
  color += 1;

  int alignedCol = 0;
  char alignedOffset = 0;
  
  // Calculate which byte the character starts on, and the bit offset from that byte
  alignedCol = offset/8;
  alignedOffset = offset%8;
    
  for (int col = 0; col < fontWidth; col++) {
    if (alignedCol >= 0 && alignedOffset >= 0 && alignedCol < COLS) {
      if( color & 0x1) {          
       for (int row = 0; row < 7; row++) {
          workBuffer[row*COLS + alignedCol] |=
                    ((font[fontOffset][col] >> row) & 0x1) << alignedOffset;
       }
      }
      if( color & 0x2) {
       for (int row = 0; row < 7; row++) {
          workBuffer[(row + 7)*COLS + alignedCol] |=
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
// @offset  byte offset to display string
// @color   String color (0 = green, 1 = red, 2 = yellow)
// @spacing Amount of space between characters
void drawString(char* string, char length, int offset, unsigned char color, unsigned int spacing = 1)
{
  for (int i = 0; i < length; i++) {
    drawChar(string[i], offset, color);
    offset += fontWidth + spacing;
  }
} 


// Initialize the IO ports
void setup()
{
  setupVideoBuffer(DOUBLE_BUFFER);
  
  Serial.begin(9600);

  for (int i = 0; i < 7; i++) {
    userString[i] = startMessage[i];
  }
  
  userStringLen = 7;
  scrollPosition = COLS*8;
  
  userStringInputLen = 0;

}
 

// Main loop
void loop()
{
  // Look for new serial input
  if (Serial.available() > 0) {
//    char a = Serial.read();
    userStringInput[userStringInputLen] = Serial.read();
//    userStringInput[userStringInputLen] = a;

    Serial.print(userStringInput[userStringInputLen]);

    // On enter, drop the message
    if (userStringInput[userStringInputLen] == '?') {
       
      // Copy over the data...
      userStringLen = userStringInputLen;
      userStringInputLen = 0;
      scrollPosition = COLS*8;
      
      // then copy over the data
      for (int i = 0; i < userStringLen; i++) {
        userString[i] = userStringInput[i];
      }
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
    scrollPosition = COLS*8;
  }
}

  
#if 0
  // Static scroll demo
  char testStr[] = "just look at this awesome led sign    just look at it";
  for (int i = 80; i > -53*6; i--) {
    clearVideoBuffer();
    drawString(testStr, 53, i, 0);
    flipVideoBuffer();
    delay(160);
  }


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

