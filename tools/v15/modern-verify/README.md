# Independent modern RBXL verifier

This read-only Rust helper decodes the **actual binary file**, including its Zstandard/LZ4 chunks, with pinned `rbx_binary 3.0.1` and `rbx_dom_weak 4.2.0`. It does not reserialize, project or strip properties before checking the file. The newer decoder supports all four currently defined PhysicalProperties discriminators, including the acoustic-absorption form.

With Rust/Cargo installed:

```sh
cargo build --locked --release --manifest-path tools/v15/modern-verify/Cargo.toml
tools/v15/modern-verify/target/release/hab-rbxl-verify path/to/HABWAS.rbxl > original-modern.json
tools/v15/modern-verify/target/release/hab-rbxl-verify Huss-A-Bomb-V15.rbxl > finished-modern.json
```

On Windows the built executable is `hab-rbxl-verify.exe`.

Output includes instance and script counts, path/class/source SHA-256 for every decoded `Source` property, whole-file SHA-256, decoder warnings and PhysicalProperties counts. The synthetic DataModel root created by the decoder is excluded from the instance count. Script paths use each instance's actual Name, matching the Python packager and the previous Go verifier.

Any decode error exits unsuccessfully. Warnings are reported rather than suppressed. A successful structural decode is not a Roblox Studio playtest and cannot establish live animation permissions, marketplace availability or gameplay behavior.

`Cargo.lock` pins the complete dependency resolution. Build products are ignored by Git.
