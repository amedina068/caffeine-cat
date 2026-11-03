# Caffeine Cat

Caffeine Cat is a small macOS app that keeps the Mac awake. It runs `/usr/bin/caffeinate` while the cat drinks coffee.

The app has a window and a menu bar item. The menu bar item opens a small panel with the same cat. You can turn the cat on and off from both. The colors follow the light or dark appearance of the system.

## Build and install

1. Run `./build.sh`. The app goes to `build/Caffeine Cat.app`.
2. To copy the app to `/Applications`, run `./build.sh --install`.

The build needs the Xcode command line tools and macOS 14 or later.

## How it works

- When the cat is awake, the app runs `caffeinate -dims -w <app pid>`.
- If "Mantener la pantalla encendida" is off, the app uses `-ims`. The screen can then turn off, but the Mac does not sleep.
- The `-w` flag connects caffeinate to the app. If the app stops or crashes, caffeinate stops too.
- If you close the window, the app stays in the menu bar. It does not show in the Dock or in Cmd+Tab until you open the window again. To stop the app, use "Quit" in the menu bar panel.

## Limits

- The `-s` flag prevents system sleep only when the Mac is on AC power.
- If you close the lid of a laptop without an external display, macOS sleeps. caffeinate cannot prevent this.

## Languages

The app uses the language of the Mac. It has English, Spanish, Portuguese (Brazil), French, German, Italian, Japanese, Simplified Chinese, and Korean. For other languages, the app uses English.

The texts are in `Resources/<language>.lproj/Localizable.strings`. The English text in the code is the key. To add a language, copy `en.lproj` to a new folder and translate the values.

To show the app in a different language, run this command:

```sh
"/Applications/Caffeine Cat.app/Contents/MacOS/CaffeineCat" -AppleLanguages "(de)"
```

## Change the sprites

The frames in `Resources/frames` come from `tools/spritesheet.png`. If you change the sprite sheet, run this command, then build again:

```sh
python3 tools/slice_sprites.py tools/spritesheet.png Resources/frames
```

The script needs Pillow. It also writes the app icon to `Resources/icon_1024.png`.
