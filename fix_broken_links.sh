grep -oP '(?<=\]\().*?\.md(?=\))' SUMMARY.md | while read -r link; do
  if [ ! -f "$link" ]; then
    echo "ERROR: Broken link in SUMMARY.md -> $link"
  fi
done
