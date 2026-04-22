# ADR 0007: Keep Repair Separate From Install

## Status

Accepted

## Decision

The repository now treats input-method lifecycle as explicit intent-first workflows:

- `make install-ime`
  - builds `BilineIME Dev`
  - builds and installs the dev Settings app, broker, and LaunchAgent on the same lane
  - copies it into `~/Library/Input Methods`
  - refreshes local registration state
  - does **not** try to force-select the input source
- `make remove-ime`
  - removes the dev IME, dev Settings app, broker, and LaunchAgent
  - unregisters the local dev lane
  - may either preserve or purge Biline-local user data
  - does **not** try to repair system-wide text-input state unless paired with a reset action
- `make reset-ime`
  - is the explicit recovery path when Biline leaves ghost input sources, raw ids, blank rows, or broken Keyboard settings state
  - `RESET_DEPTH=refresh` refreshes local registration state only
  - `RESET_DEPTH=cache-prune` clears `IntlDataCache` and requires a reboot
  - `RESET_DEPTH=launch-services-reset` deletes the Launch Services database and requires a reboot

## Rationale

The repository previously asked install and uninstall scripts to do too much:

- replace bundles
- unregister stale paths
- rewrite local input-source state
- auto-select the dev source
- recover from already-corrupted Keyboard settings state

That made normal iteration fragile and hid the difference between:

- a healthy machine that only needs a fresh dev bundle
- a damaged text-input environment that needs cache or Launch Services repair

Separating the workflows keeps ordinary install steps conservative while still documenting a stronger recovery path for machines that have already been poisoned by stale input-source state.

## Consequences

- automatic input-source selection success is no longer part of install success
- developers should use the system UI to add or re-select `BilineIME Dev` when
  source enrollment is still incomplete after install
- higher-blast-radius reset steps are now explicit and documented instead of being hidden inside install scripts
- the primary lifecycle mental model is now `install` / `remove` / `reset`
