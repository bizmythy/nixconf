#!/usr/bin/env nu

docker ps --format "{{.ID}}" | lines | each { |id| docker kill $id }
