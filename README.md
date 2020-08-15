# kakoune-smooth-scroll
Smooth scrolling for the [Kakoune](https://kakoune.org) text editor, with inertial movement

[![demo](https://caksoylar.github.io/kakoune-smooth-scroll/kakoune-smooth-scroll-v2-60fps.gif)](https://asciinema.org/a/m0DhKbv9AjAABOABKadgeYnH6?autoplay=1&loop=1)
<br/>(click for asciicast)

This plugin implements smooth scrolling similar to various plugins for Vim/Emacs etc. such as [vim-smooth-scroll](https://github.com/terryma/vim-smooth-scroll).
It gives you better visual feedback while scrolling and arguably helps you preserve your "sense of place" when making large jumps such as when using `<c-f>/<c-b>` movements.
The latest version of the plugin adds support for many keys in `normal`, `goto` and `object` modes; see the "Configuration" section below.

For that extra fun/coolness factor it also has support for inertial scrolling, also called the "easing out" or "soft stop" effect as seen above.
This is similar to myriad plugins such as [comfortable-motion.vim](https://github.com/yuttie/comfortable-motion.vim), [vim-smoothie](https://github.com/psliwka/vim-smoothie/) and [sexy-scroller.vim](https://github.com/joeytwiddle/sexy_scroller.vim).

## Installation
Download `smooth-scroll.kak` and `smooth-scroll.py` to your `autoload` folder, e.g. into `~/.config/kak/autoload`.
Or you can put them both in any location and `source path/to/smooth-scroll.kak` in your `kakrc`.

If you are using [plug.kak](https://github.com/andreyorst/plug.kak):
```kak
plug "caksoylar/kakoune-smooth-scroll" config %{
     # configuration here
}
```

## Configuration
kakoune-smooth-scroll operates through a mapping mechanism for keys in `normal`, `goto` and `object` modes.
Mapped keys will perform their usual functions but when they need to scroll the window the scrolling will happen smoothly.

Smooth scrolling is enabled and disabled on a per-window basis using `smooth-scroll-enable` and `smooth-scroll-disable` commands.
If you would like to automatically enable it for every window, you can use window-based hooks:

```kak
hook global WinCreate .* %{ hook -once window WinDisplay .* smooth-scroll-enable }
```

### Customizing mapped keys
Keys that are mapped for each mode are customized via the `scroll_keys_normal`, `scroll_keys_goto` and `scroll_keys_object` options. If for a mode the corresponding option is not set, keys that are mapped by default are the following:

| **normal** keys                           | description                              |
| ------                                    | ------                                   |
|`<c-f>`, `<pagedown>`, `<c-b>`, `<pageup>` | scroll one page down/up                  |
|`<c-d>`, `<c-u>`                           | scroll half a page down/up               |
|`)`, `(`                                   | rotate main selection forward/backward   |
|`m`, `M`                                   | select/extend to next matching character |
|`<a-semicolon>` (`<a-;>`)                  | flip direction of selection              |
|`<percent>` (`%`)                          | select whole buffer                      |
|`n`, `<a-n>`, `N`, `<a-N>`                 | select/extend to next/previous match     |

| **goto** keys                             | description                              |
| ------                                    | ------                                   |
|`g`, `k`                                   | buffer top                               |
|`j`                                        | buffer bottom                            |
|`e`                                        | buffer end                               |
|`.`                                        | last buffer change                       |

| **object** keys                           | description                              |
| ------                                    | ------                                   |
|`p`                                        | paragraph                                |
|`i`                                        | indent                                   |
|`B`, `{`, `}`                              | braces block                             |

Default behavior is equivalent to the following configuration:

```kak
set-option global scroll_keys_normal <c-f> <c-b> <c-d> <c-u> <pageup> <pagedown> ( ) m M <a-semicolon> <percent> n <a-n> N <a-N>
set-option global scroll_keys_goto g j k e .
set-option global scroll_keys_object p i B { }
```

You can override which keys are mapped for each mode by setting the corresponding option.
For example if you only want to map page-wise motions in `normal` mode and disable any mappings for `goto` mode, you can configure it as such:

```kak
set-option global scroll_keys_normal <c-f> <c-b> <c-d> <c-u>
set-option global scroll_keys_goto
```

By default each listed key is mapped to its regular function.
You might want to customize source and destination keys for each map, especially if you are already mapping other keys to these functions.
For instance if you use `<c-j>` instead of `<c-f>` and `<c-k>` instead of `<c-b>`, you can specify the option using `src=dst` pairs:

```kak
set-option global scroll_keys_normal <c-j>=<c-f> <c-k>=<c-b> <c-d> <c-u>
```

Note that these options need to be set before smooth scrolling is enabled for a window.

### Scrolling parameters
There are a few parameters related to the scrolling behavior that are adjustable through the `scroll_options` option which is a list of `<key>=<value>` pairs. Following keys are accepted and all of them are optional:
- `speed`: number of lines to scroll per tick, `0` for inertial scrolling (default: `0`)
- `interval`: average milliseconds between each scroll (default: `10`)
- `max_duration`: maximum duration of a scroll in milliseconds (default: `500`)

The default configuration is equivalent to:

```kak
set-option global scroll_options speed=0 interval=10 max_duration=500
```

## Caveats
- Smooth scrolling is not performed for movements that do not modify the selection, such as any movement through the `view` mode. See [related Kakoune issue](https://github.com/mawww/kakoune/issues/3616)
  - Keys that scroll by page (`<c-f>`,`<c-b>`,`<c-d>`,`<c-u>`) are handled specially to work around this limitation
- Keys that modify the buffer should not be mapped, such as `u` and `U` in `normal` mode, since the implementation discards any buffer modifications made by mapped keys
- Movements that are caused by the `prompt` mode such as `/search_word<ret>` can not be mapped at the moment
- Repeating selections with `<a-.>` is not possible if the selection was made through mapped keys
- For optimal performance it uses a Python implementation which requires Python 3.6+ in path, falling back to `sh` if not available
  - This implementation utilizes Kakoune's internal [remote API](https://github.com/mawww/kakoune/blob/master/src/remote.hh), so it may break with future Kakoune versions
  - A more performant implementation with pure `kak`/`sh` should be possible if [timer hooks](https://github.com/mawww/kakoune/issues/2337#issuecomment-416531650) become available

## Acknowledgments
Thanks @Screwtapello and @Guest0x0 for valuable feedback and fixes!

## License
MIT
