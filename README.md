# kakoune-smooth-scroll
Smooth scrolling for the [Kakoune](https://kakoune.org) text editor, with inertial movement

<a href="https://asciinema.org/a/348495?autoplay=1&loop=1" target="_blank"><img src="https://asciinema.org/a/348495.svg" width="600"/></a>

This plugin implements smooth scrolling similar to various plugins for Vim/Emacs etc. such as [vim-smooth-scroll](https://github.com/terryma/vim-smooth-scroll).
It gives you better visual feedback while scrolling and arguably helps you preserve your "sense of place" when making large jumps such as when using `<c-f>/<c-b>` movements.

For that extra fun/coolness factor it also has support for inertial scrolling, also called the "easing out" or "soft stop" effect as seen above.
This is similar to myriad plugins such as [comfortable-motion.vim](https://github.com/yuttie/comfortable-motion.vim), [vim-smoothie](https://github.com/psliwka/vim-smoothie/) and [sexy-scroller.vim](https://github.com/joeytwiddle/sexy_scroller.vim).

## Caveats
- Relies on `vj` and `vk` for scrolling, but always moves the cursor unlike native `<c-d>/<c-u>` et al.
This is to avoid issues with scrolling across wrapped lines similar to [kakoune#1517](https://github.com/mawww/kakoune/issues/1517).
- For optimal performance it uses a Python implementation which requires Python 3.6+ in path, falling back to `sh` if not available
  - This implementation utilizes Kakoune's internal [remote API](https://github.com/mawww/kakoune/blob/master/src/remote.hh), so it may break with future Kakoune versions
  - A more performant implementation with pure `kak`/`sh` should be possible if [timer hooks](https://github.com/mawww/kakoune/issues/2337#issuecomment-416531650) become available

## Installation
Download `smooth-scroll.kak` and `smooth-scroll.py` to your `autoload` folder, e.g. into `~/.config/kak/autoload`. If you are using [plug.kak](https://gitlab.com/andreyorst/plug.kak):
```kak
plug "caksoylar/kakoune-smooth-scroll" config %{
     # mappings here
}
```

## Configuration

You need to map the necessary keys if you want to use smooth scrolling to replace the default. Below are suggested mappings with inertial scrolling (replace `0` with `1` for linear scrolling):
```kak
# suggested mappings (python)
map global normal <c-d> ': smooth-scroll  0.5 20 0<ret>'
map global normal <c-u> ': smooth-scroll -0.5 20 0<ret>'
map global normal <c-f> ': smooth-scroll  1.0 10 0<ret>'
map global normal <c-b> ': smooth-scroll -1.0 10 0<ret>'
```

If you can't use the Python version for any reason, I suggest below mappings:
```kak
# suggested mappings (sh)
map global normal <c-d> ': smooth-scroll  0.5 40 2<ret>'
map global normal <c-u> ': smooth-scroll -0.5 40 2<ret>'
map global normal <c-f> ': smooth-scroll  1.0 20 2<ret>'
map global normal <c-b> ': smooth-scroll -1.0 20 2<ret>'
```

You can play with the second and third parameters to find the feel that you like. See `:smooth-scroll` function documentation for details.

## License
MIT
