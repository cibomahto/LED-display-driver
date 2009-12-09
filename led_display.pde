#define columnData  2
#define columnClock 3

unsigned char rowPins[] = {4, 5, 6, 7, 8, 9, 10};

unsigned char testPatternA[] = {170,  85, 170,  85, 170,  85, 170,  85, 170,  85, 
                                170,  85, 170,  85, 170,  85, 170,  85, 170,  85};

unsigned char testPatternB[] = {0xb6, 0x6d, 0xdb, 0xb6, 0x6d, 0xdb, 0xb6, 0x6d, 0xdb, 0xb6,
                                0x6d, 0xdb, 0xb6, 0x6d, 0xdb, 0xb6, 0x6d, 0xdb, 0xb6, 0x6d,
                                0xdb, 0xb6, 0x6d, 0xdb, 0xb6, 0x6d, 0xdb, 0xb6, 0x6d};
                               
                               
// Initialize the IO ports
void setup()
{
  pinMode(columnData, OUTPUT);
  pinMode(columnClock, OUTPUT); 
  digitalWrite(columnData, LOW);
  digitalWrite(columnClock, LOW);
  
  for (int i = 0; i < sizeof(rowPins); i++) {
    pinMode(rowPins[i], OUTPUT);
    digitalWrite(rowPins[i], LOW);
  }
}

// Draw a full row onto the screen
// Data should be in raw screen format: interleved bytes of green and red data.
void drawRow(unsigned char* screenData, unsigned char row)
{
  // Just dump each byte to the screen
  for (int i= 0; i < 20; i++) {
    shiftOut(columnData, columnClock, MSBFIRST, screenData[i]);
  }
  
  digitalWrite(rowPins[row], HIGH);
  delayMicroseconds(800);
  digitalWrite(rowPins[row], LOW);
}

 
// Main loop
void loop()
{
  drawRow(testPatternB,     0);
  drawRow(testPatternB + 1, 1);  
  drawRow(testPatternB + 2, 2);
  drawRow(testPatternB,     3);
  drawRow(testPatternB + 1, 4);  
  drawRow(testPatternB + 2, 5);
  drawRow(testPatternB,     6);
  
//  delay(20);
}
