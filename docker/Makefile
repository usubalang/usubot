# Assuming that an `usuba` docker image has already been registered.

.PHONY: build run

build: secret/config.toml secret/usubot.private-key.pem
	docker build					\
		 --tag=usubot				\
		 .

run:
	docker run usubot
