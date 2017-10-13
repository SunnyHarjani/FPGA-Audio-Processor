#include "terasic_includes.h"
#include "mem_verify.h"
#include "system.h"
#include "alt_types.h"
#include "sys/alt_irq.h"
#include "altera_avalon_pio_regs.h"

alt_u32 *play_btn_ptr = (alt_u32 *) PLAY_BTN_IN_BASE;
alt_u32 *record_btn_ptr = (alt_u32 *) RECORD_BTN_IN_BASE;
alt_u32 *sync_ptr = (alt_u32 *) SYNC_IN_BASE;
//alt_u32 *sdram_base_ptr = (alt_u32 *) SDRAM_BASE;
alt_u32 *sdram_base_ptr = (alt_u32 *)(8000);
alt_u32 *sdram_current_ptr = (alt_u32 *) SDRAM_BASE;
//alt_u32 *sdram_max_ptr = (alt_u32 *)((SDRAM_BASE + SDRAM_SPAN)/4);
alt_u32 *sdram_max_ptr = (alt_u32 *) (1000000);
//alt_u32 *led_out_ptr = (alt_u32 *) LED_OUT_BASE;
alt_u32 *data_in_ptr = (alt_u32 *) DATA_IN_BASE;
alt_u32 *data_out_ptr = (alt_u32 *) DATA_OUT_BASE;

typedef enum {
	IDLE, PLAYING, RECORDING
} state;
state currentState = IDLE;

// Declare a global variable to hold the edge capture value.
volatile int edge_capture;

static void recordAudio(alt_u32 BaseAddr, alt_u32 ByteLen, alt_u32 InitValue) {

	bool bPass = TRUE;
	alt_u32 szData[1025];
	alt_u32 szRead[1025];
	int i, nRemainedLen, nAccessLen;
	alt_u32 *pDes, *pSrc, nItemNum, nPos;

	int nProgressIndex = 0;
	alt_u32 szProgress[10];

	for (i = 0; i < 10; i++) {
		szProgress[i] = ByteLen / 10 * (i + 1);
	}

	nItemNum = sizeof(szData) / sizeof(szData[0]);
	for (i = 0; i < nItemNum; i++) {
		if (i == 0)
			szData[i] = InitValue;
		else
			szData[i] = szData[i - 1] * 13;
	}
	szData[nItemNum - 1] = 0xAAAAAAAA;
	szData[nItemNum - 2] = 0x55555555;
	szData[nItemNum - 3] = 0x00000000;
	szData[nItemNum - 4] = 0xFFFFFFFF;

	// write
	pDes = (alt_u32 *) BaseAddr;
	nAccessLen = sizeof(szData);
	nPos = 0;
	while (nPos < ByteLen) {
		nRemainedLen = ByteLen - nPos;
		if (nAccessLen > nRemainedLen)
			nAccessLen = nRemainedLen;
		memcpy(pDes, szData, nAccessLen);
		pDes += nAccessLen / 4;
		nPos += nAccessLen;

		}
	}

	//alt_dcache_flush_all();

static void playAudio(alt_u32 BaseAddr, alt_u32 ByteLen, alt_u32 InitValue) {

	bool bPass = TRUE;
	alt_u32 szData[1025];
	alt_u32 szRead[1025];
	int i, nRemainedLen, nAccessLen;
	alt_u32 *pDes, *pSrc, nItemNum, nPos;

	int nProgressIndex = 0;
	alt_u32 szProgress[10];

	// read & verify
	pSrc = (alt_u32 *) BaseAddr;
	nAccessLen = sizeof(szRead);
	nPos = 0;
	while (bPass && nPos < ByteLen) {
		nRemainedLen = ByteLen - nPos;
		if (nAccessLen > nRemainedLen)
			nAccessLen = nRemainedLen;
		// memset(szRead, 0xAA, nAccessLen); // reset content
		memcpy(szRead, pSrc, nAccessLen);
		// verify
		nItemNum = nAccessLen / 4;
		for (i = 0; i < nItemNum && bPass; i++) {
			if (szRead[i] != szData[i]) {
				bPass = FALSE;
			}
		}
		//
		pSrc += nItemNum;
		nPos += nAccessLen;
	}
}
static void playIsr(void* context) {
	// Cast context to edge_capture's type. It is important that this
	//	be declared volatile to avoid unwanted compiler optimization.
	volatile int* edge_capture_ptr = (volatile int*) context;

	currentState = PLAYING;
	sdram_current_ptr = sdram_base_ptr;

	// Read the edge capture register on the button PIO.
	// Store value.
	*edge_capture_ptr = IORD_ALTERA_AVALON_PIO_EDGE_CAP(PLAY_BTN_IN_BASE);

	// Write to the edge capture register to reset it.
	IOWR_ALTERA_AVALON_PIO_EDGE_CAP(PLAY_BTN_IN_BASE, 0);

	// Read the PIO to delay ISR exit. This is done to prevent a
	// spurious interrupt in systems with high processor -> pio
	// latency and fast interrupts.
	IORD_ALTERA_AVALON_PIO_EDGE_CAP(PLAY_BTN_IN_BASE);
}

static void recordIsr(void* context) {
	// Cast context to edge_capture's type. It is important that this
	//	be declared volatile to avoid unwanted compiler optimization.
	volatile int* edge_capture_ptr = (volatile int*) context;

	currentState = RECORDING;
	sdram_current_ptr = sdram_base_ptr;

	// Read the edge capture register on the button PIO.
	// Store value.
	*edge_capture_ptr = IORD_ALTERA_AVALON_PIO_EDGE_CAP(RECORD_BTN_IN_BASE);

	// Write to the edge capture register to reset it.
	IOWR_ALTERA_AVALON_PIO_EDGE_CAP(RECORD_BTN_IN_BASE, 0);

	// Read the PIO to delay ISR exit. This is done to prevent a
	// spurious interrupt in systems with high processor -> pio
	// latency and fast interrupts.
	IORD_ALTERA_AVALON_PIO_EDGE_CAP(RECORD_BTN_IN_BASE);
}

static void syncIsr(void* context) {
	// Cast context to edge_capture's type. It is important that this
	//	be declared volatile to avoid unwanted compiler optimization.
	volatile int* edge_capture_ptr = (volatile int*) context;

	if (currentState == RECORDING) {
		//memcpy(sdram_current_ptr++, data_in_ptr, DATA_IN_DATA_WIDTH);
		memcpy(sdram_current_ptr++, data_in_ptr, DATA_OUT_DATA_WIDTH);
		//recordAudio(SDRAM_BASE, SDRAM_SPAN, *data_in_ptr);
		alt_dcache_flush_all();

		//*sdram_current_ptr++ = *data_in_ptr;
	} else if (currentState == PLAYING) {
		//*data_out_ptr = *sdram_current_ptr++;
		//memcpy(data_out_ptr, sdram_current_ptr++, DATA_OUT_DATA_WIDTH);
		memcpy(data_out_ptr, sdram_current_ptr++, DATA_OUT_DATA_WIDTH);
		//playAudio(SDRAM_BASE, SDRAM_SPAN, *data_in_ptr);
	}
	if (sdram_current_ptr >= sdram_max_ptr) {
		sdram_current_ptr = sdram_base_ptr;
		if (currentState == RECORDING) {
			currentState = PLAYING;
		} else if (currentState == PLAYING) {
			currentState = IDLE;
		}
	}

	//memcpy(data_out_ptr, data_in_ptr, DATA_IN_DATA_WIDTH); // Passthrough

	// Read the edge capture register on the button PIO.
	// Store value.
	*edge_capture_ptr = IORD_ALTERA_AVALON_PIO_EDGE_CAP(SYNC_IN_BASE);

	// Write to the edge capture register to reset it.
	IOWR_ALTERA_AVALON_PIO_EDGE_CAP(SYNC_IN_BASE, 0);

	// Read the PIO to delay ISR exit. This is done to prevent a
	// spurious interrupt in systems with high processor -> pio
	// latency and fast interrupts.
	IORD_ALTERA_AVALON_PIO_EDGE_CAP(SYNC_IN_BASE);
}

int main() {
	alt_u32 zero = 0;

	//memset(sdram_current_ptr, 0, SDRAM_SPAN);
	//memset(sdram_current_ptr, 0, 0x3FFFFFF);

/*
	 for (sdram_current_ptr = sdram_base_ptr; sdram_current_ptr < sdram_max_ptr; sdram_current_ptr += 1) {
	 memcpy(sdram_current_ptr, &zero, DATA_IN_DATA_WIDTH);
	 //sdram_current_ptr = zero;
	 } */

	// Recast the edge_capture pointer to match the
	//	alt_irq_register() function prototype.
	 void* edge_capture_ptr = (void*) &edge_capture;

	// Enable all 4 button interrupts.
	IOWR_ALTERA_AVALON_PIO_IRQ_MASK(PLAY_BTN_IN_BASE, 0xf);
	IOWR_ALTERA_AVALON_PIO_IRQ_MASK(RECORD_BTN_IN_BASE, 0xf);
	IOWR_ALTERA_AVALON_PIO_IRQ_MASK(SYNC_IN_BASE, 0xf);

	// Reset the edge capture register.
	IOWR_ALTERA_AVALON_PIO_EDGE_CAP(PLAY_BTN_IN_BASE, 0x0);
	IOWR_ALTERA_AVALON_PIO_EDGE_CAP(RECORD_BTN_IN_BASE, 0x0);
	IOWR_ALTERA_AVALON_PIO_EDGE_CAP(SYNC_IN_BASE, 0x0);

	// Register the ISR.
	alt_ic_isr_register(PLAY_BTN_IN_IRQ_INTERRUPT_CONTROLLER_ID,
			PLAY_BTN_IN_IRQ, playIsr, edge_capture_ptr, 0x0);
	alt_ic_isr_register(RECORD_BTN_IN_IRQ_INTERRUPT_CONTROLLER_ID,
			RECORD_BTN_IN_IRQ, recordIsr, edge_capture_ptr, 0x0);
	alt_ic_isr_register(SYNC_IN_IRQ_INTERRUPT_CONTROLLER_ID, SYNC_IN_IRQ,
			syncIsr, edge_capture_ptr, 0x0);

	while (1) {
		switch (edge_capture) {
		case PLAY_BTN_IN_IRQ:
			//*led_out_ptr = 0b0000001;
			edge_capture = 0;
			break;
		case RECORD_BTN_IN_IRQ:
			//*led_out_ptr = 0b0000010;
			edge_capture = 0;
			break;
		case SYNC_IN_IRQ:
			//*led_out_ptr = 0b0000010;
			edge_capture = 0;
			break;
		default:
			//*led_out_ptr = 0b0000011;
			break;
		}
	}

	while (1) {
	}
	return 0;
}
