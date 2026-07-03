#!/bin/bash

COMMAND=$1

if [ "$COMMAND" = "run" ]; then
    echo "Starting PocketBase dev server on http://0.0.0.0:8090..."
    go run . serve --http="0.0.0.0:8090"
elif [ "$COMMAND" = "build" ]; then
    echo "Building Linux production binary..."
    GOOS=linux GOARCH=amd64 go build -o kitnabacha
    echo "Done! Saved as: kitnabacha"
else
    echo "Usage: ./build.sh {run|build}"
    exit 1
fi
