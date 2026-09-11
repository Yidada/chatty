# Four-platform release alignment

The same product release uses one version and the shared [activity contract](activity-contract.md). Platform build numbers may differ. Web remains a separate Sites checkout; its source revision is pinned in [0.2.0.json](0.2.0.json).

Run the read-only check before starting parallel work:

```sh
python3 scripts/check-release-alignment.py --web-repo /path/to/web-checkout
```

Omit `--web-repo` when the Web checkout is at `<repository>/web`. The check reads Android versionName, Apple generator and generated project versions, Web package version, and matching contract snapshots. It does not prove behavioral parity or publication.

## Release checklist

1. Freeze the product version, contract and source revisions. Preserve account/workspace isolation and uncertain-send handling.
2. Build and test Web, Android, iOS and macOS in independent checkouts in parallel. Use the contract acceptance scenarios on every platform.
3. Record each channel independently, including validation evidence and any limitations:

| Channel | Required delivery evidence |
| --- | --- |
| Web | Successful Sites deployment and exact URL |
| Android | APK identity/version/signature/hash; installation and synthetic-device result; label debug acceptance builds |
| iOS | Archive/upload, Apple processing completion, TestFlight group assignment and tester availability |
| macOS | Developer ID signature, notarization, DMG hash and installation/startup verification |

4. Update the release record with observed results. Keep private account identifiers, signing material and raw logs out of source control.
5. Report partial availability accurately. One successful channel does not imply the other three are available. A receipt conflict or invalid response cannot be presented as a completed task.

These files define a repeatable parallel release process. They do not configure CI or unattended store publishing. Apple processing, account authorization and distribution checks remain separate steps.
