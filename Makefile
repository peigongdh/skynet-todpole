SKYNET_PATH = skynet
TARGET = cservice/httppack.so

$(TARGET) : src/lua-httppack.c
	gcc -Wall -O2 --shared -fPIC -o $@ $^ -I$(SKYNET_PATH)/skynet-src

clean :
	rm $(TARGET)
