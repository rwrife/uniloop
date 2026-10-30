# Windows Store MSIX build workflow

Use the **Windows Store MSIX** workflow to generate:

- `build/windows/` export output (`uniloop.exe` + `uniloop.pck`)
- an **unsigned** Store submission MSIX package

The workflow does **not** publish to Partner Center. It only builds downloadable artifacts.

## Before you run it

Collect these exact values from Partner Center for the app and map them to workflow inputs:

| Partner Center field | Workflow input name | Example value |
| --- | --- | --- |
| `Package/Identity/Name` | `store_identity_name` | `Infinityball.UniloopRacing` |
| `Package/Identity/Publisher` | `store_publisher` | `CN=874CA4CF-90B8-4C53-AFBC-CCAC42030583` |
| `Package/Properties/PublisherDisplayName` | `publisher_display_name` | `Infinityball` |

These are manifest identity metadata, not secrets. Prefer **Actions variables** for them.

You can provide defaults as repository **Actions variables** and still override at dispatch time:

| Recommended repository variable | Used when input is blank |
| --- | --- |
| `WINDOWS_STORE_IDENTITY_NAME` | `store_identity_name` |
| `WINDOWS_STORE_PUBLISHER` | `store_publisher` |
| `WINDOWS_STORE_PUBLISHER_DISPLAY_NAME` | `publisher_display_name` |
| `WINDOWS_STORE_PACKAGE_DISPLAY_NAME` (optional) | `package_display_name` |

Compatibility aliases are also accepted if already configured: `STORE_IDENTITY_NAME`, `STORE_PUBLISHER`, `PUBLISHER_DISPLAY_NAME`, `PACKAGE_DISPLAY_NAME`, `UNILOOP_STORE_IDENTITY_NAME`, `UNILOOP_STORE_PUBLISHER`, `UNILOOP_STORE_PUBLISHER_DISPLAY_NAME`, `UNILOOP_STORE_PACKAGE_DISPLAY_NAME`.

For compatibility, the workflow also reads repository **secrets** with those same names. Value precedence is:

1. workflow_dispatch input
2. repository variable
3. repository secret
4. built-in fallback (`package_display_name` only, defaults to `Uniloop`)

The workflow will fail if these values are missing or malformed, and it will not invent fallback identity metadata.
`PFN`, `SID`, and Store ID are not substitutes for these manifest fields.

## Run in GitHub Actions

Open **Actions → Windows Store MSIX → Run workflow** and provide:

- `source_ref` (default `main`)
- `package_version` in `major.minor.build.revision` format, numeric only (each segment 0–65535)
- `store_identity_name` (optional override; otherwise variable default is used)
- `store_publisher` (optional override; otherwise variable default is used)
- `publisher_display_name` (optional override; otherwise variable default is used)
- `package_display_name` (optional; otherwise variable default is used, then `Uniloop`)

## Download and submit

After the run completes, download both artifacts:

1. `uniloop-windows-release-files-<package_version>`
2. `uniloop-windows-store-msix-<package_version>`

Submit the `.msix` from the second artifact in Partner Center.

## Signing behavior

The generated MSIX is intentionally **unsigned** for Store ingestion and may not install directly on local test machines.

For Microsoft Store distribution, you do **not** need to buy a signing certificate for this workflow. The Store signs submitted packages during certification/distribution (official reference: https://learn.microsoft.com/en-us/windows/msix/package/signing-package-overview).
