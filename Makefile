all:
	./build

clean:
	./clean

cleantarget:
	./clean target

cleandownloads:
	./clean downloads

cleanall:
	./clean all

distclean: cleanall
	
.PHONY: all clean cleantarget cleandownloads cleanall distclean
