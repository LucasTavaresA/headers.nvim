# headers.nvim

Zero-config header/footer warnings.

Turn on notifications in [Breaking Changes](https://github.com/LucasTavaresA/headers.nvim/issues/1) if using this plugin.

## Contents

- [Installation](#installation)
- [Options](#options)

## Installation

[packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
	"lucastavaresa/headers.nvim",
	config = function()
		require("headers").setup()
	end,
}
```

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
	"lucastavaresa/headers.nvim",
	config = function ()
		require("headers").setup()
	end,
}
```

## Keybindings

There is no keybindings by default.

Those are all the available functions:

```lua
-- Prepends/Appends the hovered header/footer
vim.keymap.set("n", "<space>H", require("headers").fix_hovered)
-- Ignore warnings for the current buffer root
vim.keymap.set("n", "<space>I", require("headers").ignore)
```

## Options

The setup function receives a table with the options, these are the default values:

```lua
{
	code_paths = {}, -- {} will warn everywhere, set one or more folders to warn only in those folders
	paths_file = vim.fn.stdpath("data") .. "/headers.nvim/paths.lua",
	non_code = { "sh", "zsh", "bash", "fish", "vim", "markdown", "txt", "json", "yaml", "toml", "ini", "html", "css", "sql", "xml", "cmake", "make", "diff", "patch", "git", "gitcommit", "gitconfig", "gitignore", "gitattributes", },
}
```
