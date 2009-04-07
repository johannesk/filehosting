
all: io2io web-c

clean: io2io-clean web-c-clean

io2io:
	make -C lib/io2io

io2io-clean:
	make -C lib/io2io clean

web-c:
	make -C lib/filehosting/web

web-c-clean:
	make -C lib/filehosting/web clean
