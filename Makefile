DOCKER_IMG = cl-bbs
APP_VERSION = $(shell git describe --tags 2> /dev/null || printf 0.1.0)
VERSION := latest
PUBLIC_IMG = lerax/$(DOCKER_IMG):$(VERSION)
ROS_TEST_FLAGS = -e "(sb-ext:disable-debugger)" -s cl-bbs/tests

lint:
	mallet --format line src tests

lint-fix:
	mallet --fix src tests

docker-lint:
	docker run --rm -t -v $(PWD):/src fukamachi/mallet:latest --format line src tests

install-deps:
	ros install qlot
	qlot install

server:
	./roswell/cl-bbs-server.ros

docker-build:
	docker build --build-arg APP_VERSION=$(APP_VERSION) -t $(DOCKER_IMG) .

docker-shell: docker-build
	docker run --rm -it --entrypoint=/bin/bash $(DOCKER_IMG)

docker-run: docker-build
	# Note: default SchemeBBS port is 8222.
	docker run --rm -it -p 8222:8222 -v $(PWD)/data:/cl-bbs/data $(DOCKER_IMG)

.PHONY: check docker-check docker-build docker-lint lint lint-fix

check:
	ros $(ROS_TEST_FLAGS) -e '(asdf:test-system :cl-bbs/tests)'

docker-check: docker-build
	docker run --rm --entrypoint=ros -e DEBUG -e ACTIONS_STEP_DEBUG \
           $(DOCKER_IMG) $(ROS_TEST_FLAGS) -e '(asdf:test-system :cl-bbs/tests)'
