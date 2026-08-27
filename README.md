# The Bone Runner

A 2D Unreal Engine game. Fight skeletons, stay out of the traps, and make it through to win.

## Play

- Run, jump, and attack your way through a dungeon
- Take down skeletons before they take you down
- Watch the floor — spike traps and slicers will end the run
- Reach the end to win

Unreal Engine 5.8 project. Open `TheBoneRun.uproject`. The game starts on the main menu.

## Requirements

- Unreal Engine 5.8
- Android SDK / NDK / JDK under `F:\Unreal Engine\Android` (local machine paths)
- Signing keystore + passwords live in gitignored files (see below)

## Android signing (local only)

These files are **not** committed:

| File | Purpose |
|------|---------|
| `Build/Android/thebonerun-release.keystore` | Release signing keystore |
| `Build/Android/key.properties` | Keystore passwords + alias |
| `Config/UserEngine.ini` | UE signing passwords + local SDK/NDK/JDK paths |

If you still have an older `redhood-release.keystore` locally, rename it to `thebonerun-release.keystore`. The key alias inside the keystore stays `redhood` so existing signing still works.

`Config/DefaultEngine.ini` stores non-secret Android settings (`PackageName`, `KeyStore` filename, `KeyAlias`, version).

## Shipping packaging

Default and platform `*Game.ini` files use `BuildConfiguration=PPBC_Shipping` with `ForDistribution=True`.
