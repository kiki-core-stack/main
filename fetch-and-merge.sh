#!/bin/bash

set -e
git fetch https://github.com/kiki-core-stack/main main
git merge FETCH_HEAD
