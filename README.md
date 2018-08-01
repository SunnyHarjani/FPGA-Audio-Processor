# FPGA_Audio_Processor
Records up to 30 minutes of audio using an Altera Cyclone V FPGA. Audio is stored as 16 bit 44 kHz samples in SDRAM using a custom DMA controller.  A custom ADC & DAC handle audio recording and playback. Users can alter the sound using custom high pass and low pass filters. Built using VHDL and C.
