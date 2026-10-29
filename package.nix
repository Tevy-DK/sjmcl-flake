{
  lib,
  stdenv,
  fetchurl,
  patchelf,
  python3,
  wrapGAppsHook3,
  makeDesktopItem,
  # Runtime libraries.
  glib,
  gtk3,
  gdk-pixbuf,
  cairo,
  pango,
  fontconfig,
  dbus,
  libsoup_3,
  webkitgtk_4_1,
  libgcc,
  # Desktop integration / GSettings schemas.
  gsettings-desktop-schemas,
  hicolor-icon-theme,
}:

let
  desktopItem = makeDesktopItem {
    name = "SJMCL";
    desktopName = "SJMCL";
    genericName = "Minecraft Launcher";
    comment = "A Minecraft launcher from SJMC";
    exec = "SJMCL %U";
    icon = "SJMCL";
    terminal = false;
    categories = [ "Game" ];
    startupWMClass = "SJMCL";
    mimeTypes = [
      "application/zip"
      "x-scheme-handler/sjmcl"
    ];
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "sjmcl";
  version = "1.4.0";

  # The portable build is a single self-contained ELF: the Tauri frontend is
  # linked in and the resource files are appended to the binary as a ZIP.
  src = fetchurl {
    url = "https://github.com/UNIkeEN/SJMCL/releases/download/v${finalAttrs.version}/SJMCL_${finalAttrs.version}_linux_x86_64_portable";
    hash = "sha256-QN2uVp4OerVq/hXAXgRBwStrr9YdlsKPtMgsYt9VYtQ=";
  };

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  # The portable binary appends its resources as a ZIP plus a 12-byte "PORT"
  # trailer, and in that mode writes its config next to the executable.  A Nix
  # store path is read-only, so install the resources where Tauri looks for
  # them in a regular bundle ($out/lib/SJMCL) and drop the trailer to disable
  # portable mode.  A patchelf pass would also discard the appended data.
  dontStrip = true;
  dontPatchELF = true;

  nativeBuildInputs = [
    patchelf
    python3
    wrapGAppsHook3
  ];

  buildInputs = [
    glib
    gtk3
    gdk-pixbuf
    cairo
    pango
    fontconfig
    dbus
    libsoup_3
    webkitgtk_4_1
    gsettings-desktop-schemas
    hicolor-icon-theme
  ];

  installPhase = ''
    runHook preInstall

    install -d "$out/bin" "$out/lib/SJMCL"
    python3 - "$src" "$out/bin/SJMCL" "$out/lib/SJMCL" \
      "${stdenv.cc.libc}/lib/ld-linux-x86-64.so.2" \
      "${lib.makeLibraryPath [
        glib
        gtk3
        gdk-pixbuf
        cairo
        pango
        fontconfig
        dbus
        libsoup_3
        webkitgtk_4_1
        libgcc
      ]}" <<'PY'
import io
import os
import struct
import subprocess
import sys
import tempfile
import zipfile

src, dst, resource_dir, interpreter, rpath = sys.argv[1:]
data = open(src, "rb").read()

magic, elf_size, zip_size = data[-12:-8], *struct.unpack("<II", data[-8:])
assert magic == b"PORT", f"unexpected portable trailer: {magic!r}"
assert elf_size + zip_size + 12 == len(data), "portable trailer sizes are inconsistent"
zip_data = data[elf_size : elf_size + zip_size]
assert zip_data[:4] == b"PK\x03\x04", "portable resource payload is not a ZIP archive"

with zipfile.ZipFile(io.BytesIO(zip_data)) as archive:
    archive.extractall(resource_dir)

with tempfile.TemporaryDirectory() as tmp:
    elf = os.path.join(tmp, "SJMCL")
    with open(elf, "wb") as f:
        f.write(data[:elf_size])
    subprocess.check_call([
        "patchelf",
        "--set-interpreter", interpreter,
        "--set-rpath", rpath,
        elf,
    ])
    patched_elf = open(elf, "rb").read()

# Install only the patched ELF: without the PORT trailer the application
# treats itself as a bundled (non-portable) install.
with open(dst, "wb") as f:
    f.write(patched_elf)
os.chmod(dst, 0o755)
PY

    install -Dm644 "$out/lib/SJMCL/assets/icons/icon.png" "$out/share/icons/hicolor/512x512/apps/SJMCL.png"
    install -Dm644 "${desktopItem}/share/applications/SJMCL.desktop" "$out/share/applications/SJMCL.desktop"

    runHook postInstall
  '';

  meta = {
    description = "Minecraft launcher from SJMC (SJTU Minecraft Club)";
    longDescription = ''
      SJMCL is a Minecraft launcher developed by the SJTU Minecraft Club.
      This package repackages the upstream self-contained Linux x86_64
      portable build for NixOS and other Nix systems.
    '';
    homepage = "https://github.com/UNIkeEN/SJMCL";
    license = lib.licenses.gpl3Plus;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "SJMCL";
  };
})
