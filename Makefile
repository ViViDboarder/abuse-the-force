# Simple makefile to call rake
.PHONY: default

default:
	rake install

build:
	rake build

install:
	rake install
