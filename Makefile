all: build

build:
	docker build -t refractix/tinc:latest .

run: build
	docker run --rm -v ${PWD}/config:/config -e TINC_ADDRESS=tinc.nordmann.ninja --cap-add=NET_ADMIN --name=tinc refractix/tinc:latest

test: build
	sudo rm -rf ./config
	docker run --rm -v ${PWD}/config:/config -e TINC_ADDRESS=tinc.nordmann.ninja --cap-add=NET_ADMIN --name=tinc refractix/tinc:latest

conf: build
	docker run --rm -v ${PWD}/config:/config -e TINC_ADDRESS=tinc.nordmann.ninja refractix/tinc:latest genconf

publish: build
	docker push refractix/tinc:latest