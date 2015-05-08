RUSTC=rustc
RUSTCFLAGS=-C relocation-model=dynamic-no-pic -C no-stack-check \
	-O -Z no-landing-pads \
	-A dead-code \
	-W trivial-casts -W trivial-numeric-casts
LD=ld
AS=nasm
QEMU=qemu-system-i386

all: harddrive.bin

kernel.bin: src/kernel.rs
	$(RUSTC) $(RUSTCFLAGS) --target i686-unknown-linux-gnu --crate-type lib -o kernel.rs.o --emit obj $<
	$(LD) -m elf_i386 -o $@ -T src/kernel.ld kernel.rs.o
	rm kernel.rs.o

filesystem/%.bin: src/%.rs
	$(RUSTC) $(RUSTCFLAGS) --target i686-unknown-linux-gnu --crate-type lib -o "$<.o" --emit obj $<
	$(LD) -m elf_i386 -o $@ -T src/program.ld "$<.o"
	rm "$<.o"

filesystem/filesystem.asm: filesystem/test.bin
	ls filesystem | grep -v filesystem.asm | awk '{printf("file %d,\"%s\"\n", NR, $$0)}' > $@

harddrive.bin: src/loader.asm filesystem/filesystem.asm kernel.bin
	$(AS) -f bin -o $@ -ifilesystem/ -isrc/ $<

run: harddrive.bin
	$(QEMU) -enable-kvm -sdl -serial mon:stdio -net nic,model=rtl8139 -net user -hda $<

run_no_kvm: harddrive.bin
	$(QEMU) -sdl -serial mon:stdio -net nic,model=rtl8139 -net user -hda $<

run_netdev: harddrive.bin
	sudo tunctl -t tap_qemu -u "${USER}"
	sudo ifconfig tap_qemu 10.85.85.1 up
	$(QEMU) -enable-kvm -sdl -serial mon:stdio -net nic,model=rtl8139 -net dump,file=network.pcap -net tap,ifname=tap_qemu,script=no,downscript=no -hda $<
	sudo ifconfig tap_qemu down
	sudo tunctl -d tap_qemu

clean:
	rm -f *.bin filesystem/*.bin filesystem/filesystem.asm