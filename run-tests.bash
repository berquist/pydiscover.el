#!/usr/bin/env bash

cask exec emacs --batch -l ert -l pydiscover.el -l pydiscover-test.el -f ert-run-tests-batch-and-exit
