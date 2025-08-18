#!/usr/bin/env nu

let all_ids = (docker ps --format "{{.ID}}" | lines)
docker kill ...$all_ids
