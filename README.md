ranger
=============
![Neovim](https://img.shields.io/badge/NeoVim-%2357A143.svg?&style=for-the-badge&logo=neovim&logoColor=white)

[![CI Status](https://github.com/ipod825/ranger.nvim/workflows/CI/badge.svg?branch=main)](https://github.com/ipod825/ranger.nvim/actions)

## Dependency
1. [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
2. [libp.nvim](https://github.com/ipod825/libp.nvim)
3. [nerd-font](https://github.com/ryanoasis/nerd-fonts#font-installation)

## Installation
------------

Use you preferred package manager. Below we use [packer.nvim](https://github.com/wbthomason/packer.nvim) as an example.

```lua
use {'nvim-lua/plenary.nvim'}
use {'ipod825/libp.nvim'}
use {
	"ipod825/ranger.nvim",
	config = function()
		require("ranger").setup()
	end,
}
```
or

```lua
use({
	"ipod825/ranger.nvim",
	requires = { "nvim-lua/plenary.nvim", "ipod825/libp.nvim" },
	config = function()
		require("ranger").setup()
	end,
})
```

## Usage
`:help ranger` `:help ranger-customization`

## Screen Shot
* Copy/Cut/Paste in multiple windows
![copy_cut_paste](https://user-images.githubusercontent.com/1246394/189580388-793f7bb3-d7c3-4497-a3f3-6fbc7193ab0c.gif)
* Preview/Panel mode
![preview_mode](https://user-images.githubusercontent.com/1246394/189579801-22d23a08-03ee-41cc-96c1-3f94bb746995.gif)
* Inline Rename
![inline_rename](https://user-images.githubusercontent.com/1246394/189579787-245fa9ae-131b-4d73-ac6d-6b684004c7ac.gif)
* Batch Pick (visual mode) for Delete (or copy/cut)
![batch_pick](https://user-images.githubusercontent.com/1246394/189579758-1f65fd87-ab53-4802-8bec-00604028d70f.gif)
* New File/Directory
![create_dir](https://user-images.githubusercontent.com/1246394/189579774-6fc69470-a349-4b61-8304-bd63d9903446.gif)
* Sort
![sort](https://user-images.githubusercontent.com/1246394/189579838-b8a6d674-759a-40a6-996d-ada2787776fc.gif)
* Open file with external programs (rifle)
![rifle](https://user-images.githubusercontent.com/1246394/189579808-0b3dfb0c-0b14-4e24-908d-4e8b6c52b55b.gif)
* Image preview
![image_preview](https://user-images.githubusercontent.com/1246394/189579780-31764fca-9f7d-4670-b0c8-f95192918f9f.gif)
* Inline Search
![inline_search](https://user-images.githubusercontent.com/1246394/189579793-a1771cfd-9187-458f-8ce1-0a5534f095b5.gif)
