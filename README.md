# 📚 Tryptic

Directory viewer for Neovim, inspired by [Ranger](https://github.com/ranger/ranger).

The UI consists of 3 floating windows. In the center is the currently focused directory. On the left is the parent directory.
The right window contains either a child directory, or a file preview.

With default bindings use `j` and `k` (or any other motions like `G`,  `gg`, `/` etc) to navigate within the current directory.
Use `h` and `l` to switch to the parent or child directories respectively.
If the buffer on the right is a file, then pressing `l` will close Tryptic and open that file in the buffer you were just in.
You only ever control or focus the middle window.

## ✨ Features

- Rapid, intuitive directory browsing
- Extensible
- File preview
- Pretty icons
- Git signs
- Diagnostic signs
- Create files and folders
- Rename
- Delete
- Copy
- Cut 'n' paste

## ⚡️ Requirements

- Neovim >= 0.9.0
- A [Nerd Font](https://www.nerdfonts.com/) (optional, used for icons)

## 📦 Installation

Example using [Lazy](https://github.com/folke/lazy.nvim).

```lua
{
  'simonmclean/tryptic',
  dependencies = {
    'nvim-lua/plenary.nvim', -- required
    'nvim-tree/nvim-web-devicons', -- optional
    'lewis6991/gitsigns.nvim' -- optional
  }
}
```

Then call the `setup` function somewhere in your Neovim config to initialise it with the default options.

```lua
require 'tryptic'.setup()
```

## ⚙️ Configuration

Below is the default configuration. Feel free to override any of these.

Key mappings can either be a string, or a table of strings if you want multiple bindings.

```lua
require 'tryptic'.setup {
  mappings = {
    open_tryptic = '<leader>-',
    -- Everything below is buffer-local, meaning it will only apply to Tryptic windows
    show_help = 'g?',
    jump_to_cwd = '.', -- Pressing again will toggle back
    nav_left = 'h',
    nav_right = { 'l', '<CR>' },
    delete = 'd',
    add = 'a',
    copy = 'c',
    rename = 'r',
    cut = 'x', -- Pressing again will remove the item from the cut list
    paste = 'p',
    quit = 'q',
    toggle_hidden = '<leader>.'
  }
  extension_mappings = {}
  options = {
    dirs_first = true
  },
  git_signs = { -- TODO: Document this
    enabled = true,
    signs = {
      add = 'GitSignsAdd',
      add_modify = 'GitSignsAdd',
      modify = 'GitSignsChange',
      delete = 'GitSignsDelete',
      rename = 'GitSignsRename',
      untracked = 'GitSignsUntracked'
    }
  }
}
```

### Extending functionality

The `extension_mappings` property allows you add any arbitrary functionality based on the current cursor target.
You simply provide a key mapping and a function. When the mapped keys are pressed the function is invoked, and will receive a table containing the following:

```lua
{ -- TODO: Update this
  path, -- e.g. /User/Name/foo/bar.js
  display_name -- e.g. bar.js
  basename, -- e.g. bar.js
  dirname, -- e.g. /User/Name/foo/
  is_dir, -- boolean indicating whether this is a directory
  filetype, -- e.g. 'javascript'
  cutting, -- whether this has been marked for cut 'n' paste
  children, -- table containing directory contents (if applicable)
}
```

For example, if you want to make `<c-f>` search the file or directory under the cursor using [Telescope](https://github.com/nvim-telescope/telescope.nvim).

```lua
{
  extension_mappings = {
    ['<c-f>'] = function(target)
      require 'telescope.builtin'.live_grep {
        search_dirs = { target.path }
      }
    end
  }
}
```

## 🛠️ TODO

- Project
    - Github Action
        - Formating
        - Linting
        - Testing
    - Bring the readme up to date and add a screenshot
    - License
- Test
    - Extension mappings
