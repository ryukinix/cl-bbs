DOCKER_IMG = cl-bbs
APP_VERSION = $(shell git describe --tags 2> /dev/null || printf 0.1.0)
VERSION := latest
PUBLIC_IMG = ryukinix/$(DOCKER_IMG):$(VERSION)
ROS_TEST_FLAGS = -e "(sb-ext:disable-debugger)" -s cl-bbs/tests

lint:
	mallet --format line src tests

lint-fix:
	mallet --fix src tests

docker-lint:
	docker run --rm -t -v $(PWD):/app -w /app fukamachi/mallet:0.9.2 --format line src tests

install-deps:
	ros install qlot
	qlot install

server:
	./roswell/cl-bbs-server.ros

docker-build: dockerbuild

dockerbuild:
	docker build --build-arg APP_VERSION=$(APP_VERSION) --build-arg APP_COMMIT_HASH=$(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown") -t $(DOCKER_IMG) .

docker-shell: docker-build
	docker run --rm -it --entrypoint=/bin/bash $(DOCKER_IMG)

docker-run: docker-build
	# Note: default SchemeBBS port is 8222.
	docker run --rm -it -p 8222:8222 -v $(PWD)/data:/cl-bbs/data $(DOCKER_IMG)

.PHONY: check check-unit check-integration docker-check docker-build docker-lint lint lint-fix publish

check:
	ros $(ROS_TEST_FLAGS) -e '(asdf:test-system :cl-bbs/tests)'

check-unit:
	ros $(ROS_TEST_FLAGS) -e "(cl-bbs/tests:run-tests 'cl-bbs/tests:unit)"

check-integration:
	ros $(ROS_TEST_FLAGS) -e "(cl-bbs/tests:run-tests 'cl-bbs/tests:integration)"

docker-check: docker-build
	docker run --rm --entrypoint=ros -e DEBUG -e ACTIONS_STEP_DEBUG \
           $(DOCKER_IMG) $(ROS_TEST_FLAGS) -e '(asdf:test-system :cl-bbs/tests)'

publish: docker-build
	docker tag $(DOCKER_IMG) $(PUBLIC_IMG)
	docker push $(PUBLIC_IMG)

deploy: publish
	ssh starfox -t deploy apply cl-bbs

deploy-remote:
	ssh starfox -t "cd Desktop/workspace/cl-bbs && git fetch && git reset --hard origin/$(shell git rev-parse --abbrev-ref HEAD) && make deploy"
