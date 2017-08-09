git submodule update --init

cd ./skynet

make linux

cd ./3rd/lua_cjson

make

mv cjson.so ../../luaclib/cjson.so
