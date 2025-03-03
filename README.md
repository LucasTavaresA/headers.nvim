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
```

## Options

The setup function receives a table with the options, these are the default values:

```lua
{
	paths_file = vim.fn.stdpath("data") .. "/headers.nvim/paths.lua",
}
```
