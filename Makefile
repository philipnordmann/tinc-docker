all: build

build:
	docker build -t refractix/tinc:latest .

run: build
	docker run --rm -v ${PWD}/config:/config -e TINC_NAME=test -e GIT_USERNAME=${GIT_USERNAME} -e GIT_REPOSITORY=${GIT_REPOSITORY} -e GIT_TOKEN=${GIT_TOKEN} --cap-add=NET_ADMIN --name=tinc refractix/tinc:latest

test: build
	sudo rm -rf ./config
	docker run --rm -v ${PWD}/config:/config -e TINC_NAME=test -e GIT_USERNAME=${GIT_USERNAME} -e GIT_REPOSITORY=${GIT_REPOSITORY} -e GIT_TOKEN=${GIT_TOKEN} --cap-add=NET_ADMIN --name=tinc refractix/tinc:latest

publish: build
	docker push refractix/tinc:latest