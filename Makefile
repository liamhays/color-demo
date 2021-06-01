all:
	wla-z80 -o color-demo.obj color-demo.asm
	wlalink linkfile color-demo.gg
