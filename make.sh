#!/bin/bash

set -e

cd "$(dirname "$0")"

# ruby ./generate_keys.rb
ruby ./generate_licenses.rb

echo "done"