all:
	./build

clean:
	./clean

cleanroot:
	./clean root

cleandownloads:
	./clean downloads

cleanall:
	./clean all
	
.PHONY: all clean cleanroot cleandownloads cleanall
