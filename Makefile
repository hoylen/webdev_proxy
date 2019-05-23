# Makefile

.PHONY: build doc

help:
	@echo 'Targets:'
	@echo '  run-prod   - run example server in production mode'
	@echo '  run-debug  - run example server in debug mode'
	@echo
	@echo '  serve      - runs "webdev serve" (used with "debug")'
	@echo '  build      - runs "webdev build" (use before using "prod")'
	@echo
	@echo '  doc        - generate documentation'
	@echo
	@echo '  unbuild    - removes directory produced by "webdev build"'
	@echo '  clean      - deletes generated files'

#----------------------------------------------------------------
# Runs the example HTTP server

run-prod:
	dart example/example.dart

run-debug:
	dart example/example.dart --debug http://localhost:8080

#----------------------------------------------------------------
# Support for the example HTTP server

build:
	webdev build

unbuild:
	rm -rf 'build'

serve:
	webdev serve

#----------------------------------------------------------------
# Documentation

doc:
	dartdoc

#----------------------------------------------------------------
# Clean

clean: unbuild
	rm -rf doc

#EOF
