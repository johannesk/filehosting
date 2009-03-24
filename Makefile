
all: io2io

clean: io2io-clean

io2io:
	make -C lib/io2io

io2io-clean:
	make -C lib/io2io clean
