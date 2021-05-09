# todeftool

A tool for navigating [re-frame][] events, subscriptions and coeffects.

<img src="todeftool-screenshot.png" alt="Screenshot" />

## Requirements

_Note: these are targeted for macOS._

You'll need Tcl/Tk installed - provides the UI toolkit. 

`reframe-tool` - [utility][reframe-tool] that does the actual work of indexing your ClojureScript code. You can install it with brew.

	brew tap rosado/rosado
	brew install reframe-tool

This will put `reframe-tool` on your path.

## Usage

	wish todeftool.tcl "cljs:/path/to/project/src" "cljs:/other/path/src"

You can supply multiple paths, as you can see. See `reframe-tool` usage for details about the pathspec.

You'll also need to edit `todeftool.tcl` to provide command for opening your editor. See the `openEditor` command.

## License

The code is in Public Domain.

[re-frame]: https://day8.github.io/re-frame/
[reframe-tool]: https://github.com/rosado/reframe.nim