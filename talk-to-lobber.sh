#!/bin/bash
elixir --sname cli --rpc-eval lobber "Lobber.ReleaseTasks.prompt(\"$1\")"
