#!/usr/bin/env bash
# Rebuild the passcode-locked JMP page (jmp/index.html) from jmp/_build/jmp.pdf.
#
#   jmp/_build/build.sh [path/to/paper.pdf]
#
# The passcode is read from $STATICRYPT_PASSWORD, or prompted for. It is never stored.
# jmp.pdf and viewer.html hold the plaintext paper and are gitignored; only the
# encrypted jmp/index.html is committed. Run `quarto render` afterwards to copy it to docs/.
set -euo pipefail
cd "$(dirname "$0")"

if [[ $# -ge 1 ]]; then cp "$1" jmp.pdf; fi
[[ -f jmp.pdf ]] || { echo "No jmp/_build/jmp.pdf; pass the PDF path as an argument." >&2; exit 1; }

if [[ -z "${STATICRYPT_PASSWORD:-}" ]]; then
  read -rsp "Passcode: " STATICRYPT_PASSWORD; echo
  export STATICRYPT_PASSWORD
fi
if [[ ${#STATICRYPT_PASSWORD} -lt 14 ]]; then
  echo "Warning: passcode is under 14 characters; fine for a demo, use a longer one for the real paper." >&2
fi

# Embed the PDF in the viewer page
B64=$(base64 -i jmp.pdf | tr -d '\n')
python3 -c 'import sys; t=open("viewer_template.html").read(); open("viewer.html","w").write(t.replace("__PDF_B64__", sys.argv[1]))' "$B64"

# Encrypt the viewer page into jmp/index.html
rm -rf out
npx --yes staticrypt@3.5.4 viewer.html --short -c false -d out -t passcode_template.html --remember 30 \
  --template-title "Job Market Paper" \
  --template-instructions "This draft is passcode-protected. If you've received a passcode, enter it below." \
  --template-button "OPEN PAPER" \
  --template-placeholder "Passcode" \
  --template-remember "Remember me on this device" \
  --template-error "Incorrect passcode" \
  --template-color-primary "#1a5276" \
  --template-color-secondary "#f7f7f5" >/dev/null
mv out/viewer.html ../index.html
rm -rf out viewer.html

# Guard: the committed page must contain no plaintext PDF ("JVBERi" is base64 for "%PDF")
if grep -q "JVBERi" ../index.html; then
  echo "ERROR: plaintext PDF found in jmp/index.html" >&2; rm ../index.html; exit 1
fi
echo "Wrote jmp/index.html (encrypted). Next: quarto render"
