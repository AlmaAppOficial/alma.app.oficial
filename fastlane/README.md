fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios ci_beta

```sh
[bundle exec] fastlane ios ci_beta
```

CI: Build and upload to TestFlight

### ios test

```sh
[bundle exec] fastlane ios test
```

Run tests

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight (beta)

### ios release

```sh
[bundle exec] fastlane ios release
```

Build and upload to App Store (metadata + binary, sem submit)

### ios deliver_metadata_only

```sh
[bundle exec] fastlane ios deliver_metadata_only
```

Sobe APENAS metadata para a ASC — sem build, sem screenshots, sem submit

### ios submit_review_info

```sh
[bundle exec] fastlane ios submit_review_info
```

Atualiza Sign-In Information (App Review) via Spaceship — NÃO toca outros metadata

### ios verify_metadata

```sh
[bundle exec] fastlane ios verify_metadata
```

Dry-run: valida API key + metadata local, sem tocar a ASC

----


## Android

### android beta

```sh
[bundle exec] fastlane android beta
```

Build and upload to Google Play Internal track

### android release

```sh
[bundle exec] fastlane android release
```

Promote Internal → Production on Google Play

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
