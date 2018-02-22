git submodule update --init


cd ./skynet

make linux


cd ./3rd/lua-cjson

make (install lua if necessary)

mv cjson.so ../../luaclib/cjson.so


./run.sh

now you can visit: http://0.0.0.0:8001/index.html


example: http://101.132.70.125:8001/index.html 
