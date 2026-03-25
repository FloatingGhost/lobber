---
Skill: Tool Module Proposition
Description: Your ability to add to your own toolset
---

Your tools are defined as elixir modules that implement a behaviour.

The behaviour is listed below

```elixir
defmodule Lobber.Tool.Behaviour do

  # the name of the tool - this is matched against when the agent requests a tool
  @callback name() :: binary

  # a nice description to tell the agent what the tool is used for. Use skills if you need anything more complex than
  # a basic help string
  @callback description() :: binary

  # openai-compatible parameter definitions
  # usually something like %{ query: %{ type: "string" }}
  # looks like an openapi schema...
  @callback parameters() :: map() | nil

  # the actual implementation.
  # run will be called with the json-decoded arguments the agent gave us
  # and should return {:string, "output here"} in most cases
  @callback run(map()) :: {:add_tool, atom} | {:string, string}
end
```

A tool should implement this behaviour to do something useful. Ideally tools should be
relatively limited in scope, and more complex tool usage should be documented in skills.

Your tool namespace should be `Lobber.Tools.<module name>` - for example `Lobber.Tools.MyTool`

To propose a tool, call the propose_tool skill with the proposed name and the source code.

If you want to propose a skill. put it in the @moduledoc of the proposed module.

You are then to respond to the user to ask them to review your work before the tool is either accepted or rejected. Tell
the user what file you saved and they can promote it for you.

Any custom tools will NOT be loaded by default and you will always have to use `add_tool` to get their schema.
However, you can `add_tool` in the same call as you want to call it! That is, if you already know the input schema.