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


#define SINGLE_BUFFER 0
#define DOUBLE_BUFFER 1

char displayMode;   // Either SINGLE_BUFFER or DOUBLE_BUFFER

#define ROWS 7      // Note that there is a set of rows for each color, so 14 in total
#define COLS 10

// Double 80x7 bi-color video buffer
// green is arrays 0-6, red is 7-13
// Not a 2d array because we couldn't point to it.
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
#define SPICLOCK  13    //sck


char spi_transfer(volatile char data)
{
  SPDR = data;                    // Start the transmission
  while (!(SPSR & (1<<SPIF))) {}  // Wait the end of the transmission
                                  // TODO: interrupt-based display
  return SPDR;                    // return the received byte
}


int videoCurrentRow;
int videoCurrentCol;
boolean videoFlipPage;

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
  // Just set the flip flag, the buffer will flip between redraws
  videoFlipPage = true;
  
  // If we are blocking, sit here until the page flips.
  if (blocking) {
    delay(1);
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


// TODO: Make this interrupt-based!
void drawVideoBuffer()
{
  // For each row
  for (int row = 0; row < 7; row++) {
    // for each column
    for (int col = 0; col < 10; col++) {
      // Green
      spi_transfer(displayBuffer[row*COLS + 9-col]);
      
      // Then red
      spi_transfer(displayBuffer[(row+7)*COLS + 9-col]);
    }
    
    digitalWrite(rowPins[row], HIGH);
    delayMicroseconds(500);
    digitalWrite(rowPins[row], LOW);    
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
  
  // Set up Timer 2 (don't start it, though)
  TCCR2A = 0;
  TCCR2B = 0;
//  TCCR2B = (1<<CS22)|(1<<CS21)|(1<<CS20);  
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


//  Draw a letter at any point in the display buffer
//  letter  in ASCII
//  offset  in leds from the origin
//  color   String color (0 = green, 1 = red, 2 = yellow)
void drawChar(char letter, unsigned char offset, unsigned char color)
{  
  // Convert the ASCII letter to a font offset
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
        workBuffer[row*COLS + alignedCol] |= ((font[fontOffset][col] >> row) & 0x1) << alignedOffset;
      }
      if( color & 0x2) {
        workBuffer[(row + 7)*COLS + alignedCol] |= ((font[fontOffset][col] >> row) & 0x1) << alignedOffset;
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


// Initialize the IO ports
void setup()
{
  setupVideoBuffer(SINGLE_BUFFER);
  
  Serial.begin(9600);
}
 

// Main loop
void loop()
{  
  for (int i = 0; i < 16; i++) {
    clearVideoBuffer();
    drawString("HackPGH", 7, 0+i, 0);
    drawString("FTW", 3, 48+i, 2);
    
    flipVideoBuffer();
    delay(20);
  }

  for (int i = 14; i > 0; i--) {
    clearVideoBuffer();
    drawString("HackPGH", 7, 0+i, 1);
    drawString("FTW", 3, 48+i, 2);
    
    flipVideoBuffer();
    delay(20);
  }
}
