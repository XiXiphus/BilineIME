# ADR 0007: Keep Repair Separate From Install

## Status

Accepted

## Decision

The repository now treats input-method installation and local system repair as two separate workflows:

- `make install-ime`
  - builds `BilineIME Dev`
  - copies it into `~/Library/Input Methods`
  - refreshes local registration state
  - does **not** try to force-select the input source
- `make uninstall-ime`
  - removes the dev IME and dev Settings app bundles
  - unregisters the local dev lane
  - does **not** try to repair system-wide text-input state
- `make repair-ime`
  - is the explicit recovery path when Biline leaves ghost input sources, raw ids, blank rows, or broken Keyboard settings state
  - level 1 reinstalls the dev IME and dev Settings app
  - level 2 clears `IntlDataCache` and requires a reboot
  - level 3 deletes the Launch Services database and requires a reboot

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
- developers should use the system UI to add or re-select `BilineIME Dev`
- repair steps with higher blast radius are now explicit and documented instead of being hidden inside install scripts
