SHELL := /bin/bash
.PHONY: bootstrap doctor lint test build package verify
bootstrap:
	bash scripts/bootstrap.sh
doctor:
	bash scripts/doctor.sh
lint:
	node scripts/lint.mjs
	PATH="$(CURDIR)/.tools:$$PATH" .tools/actionlint
	.tools/shellcheck scripts/*.sh
	@for script in scripts/*.sh; do bash -n "$$script" || exit; done
	 swift format lint --strict --recursive Sources Tests App Package.swift scripts/icon.swift
test:
	swift test
	npm test
build:
	bash scripts/build.sh
package:
	bash scripts/package.sh
verify: lint test package
