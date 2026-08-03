# Red Hood

Unreal Engine 5.8 project configured for Android shipping builds.

## Requirements

- Unreal Engine 5.8
- Android SDK / NDK / JDK under `F:\Unreal Engine\Android` (local machine paths)
- Signing keystore + passwords live in gitignored files (see below)

## Android signing (local only)

These files are **not** committed:

| File | Purpose |
|------|---------|
| `Build/Android/redhood-release.keystore` | Release signing keystore |
| `Build/Android/key.properties` | Keystore passwords + alias |
| `Config/UserEngine.ini` | UE signing passwords + local SDK/NDK/JDK paths |

`Config/DefaultEngine.ini` stores non-secret Android settings (`PackageName`, `KeyStore` filename, `KeyAlias`, version).

## Shipping packaging

Default and platform `*Game.ini` files use `BuildConfiguration=PPBC_Shipping` with `ForDistribution=True` (same pattern as CrazyKix).
