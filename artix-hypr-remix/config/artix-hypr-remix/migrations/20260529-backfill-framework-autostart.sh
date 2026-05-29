#!/usr/bin/env bash
set -euo pipefail

# Backfill first-run and post-boot framework hooks into user Hyprland config.
target_file="$HOME/.config/hypr/hyprland.conf"
first_run_line='exec-once = bash ~/.config/artix-hypr-remix/bin/first-run.sh'
post_boot_line='exec-once = bash ~/.config/artix-hypr-remix/bin/hook.sh post-boot'

if [[ ! -f "$target_file" ]]; then
  echo "Skipping autostart backfill migration: file not found: $target_file"
  exit 0
fi

need_first_run=true
need_post_boot=true

if grep -Eq '^[[:space:]]*exec-once[[:space:]]*=[[:space:]]*bash[[:space:]]+~/.config/artix-hypr-remix/bin/first-run\.sh([[:space:]]*(#.*)?)?$' "$target_file"; then
  need_first_run=false
fi

if grep -Eq '^[[:space:]]*exec-once[[:space:]]*=[[:space:]]*bash[[:space:]]+~/.config/artix-hypr-remix/bin/hook\.sh[[:space:]]+post-boot([[:space:]]*(#.*)?)?$' "$target_file"; then
  need_post_boot=false
fi

if [[ "$need_first_run" == "false" && "$need_post_boot" == "false" ]]; then
  echo "No autostart backfill changes needed"
  exit 0
fi

temp_file="$(mktemp)"
backup_file="$target_file.bak.$(date +%s)"

cleanup() {
  rm -f "$temp_file"
}
trap cleanup EXIT

insert_after_autostart_comment() {
  awk \
    -v first_run_line="$first_run_line" \
    -v post_boot_line="$post_boot_line" \
    -v need_first_run="$need_first_run" \
    -v need_post_boot="$need_post_boot" \
    'BEGIN { inserted = 0 }
     {
       print $0
       if (inserted == 0 && $0 ~ /^[[:space:]]*# Autostart[[:space:]]*$/) {
         if (need_first_run == "true") print first_run_line
         if (need_post_boot == "true") print post_boot_line
         inserted = 1
       }
     }
     END {
       if (inserted == 0) {
         print ""
         print "# Autostart"
         if (need_first_run == "true") print first_run_line
         if (need_post_boot == "true") print post_boot_line
       }
     }' "$target_file"
}

insert_before_first_exec_once() {
  awk \
    -v first_run_line="$first_run_line" \
    -v post_boot_line="$post_boot_line" \
    -v need_first_run="$need_first_run" \
    -v need_post_boot="$need_post_boot" \
    'BEGIN { inserted = 0 }
     {
       if (inserted == 0 && $0 ~ /^[[:space:]]*exec-once[[:space:]]*=/) {
         if (need_first_run == "true") print first_run_line
         if (need_post_boot == "true") print post_boot_line
         inserted = 1
       }
       print $0
     }
     END {
       if (inserted == 0) {
         print ""
         print "# Autostart"
         if (need_first_run == "true") print first_run_line
         if (need_post_boot == "true") print post_boot_line
       }
     }' "$target_file"
}

insert_post_boot_after_first_run() {
  awk \
    -v post_boot_line="$post_boot_line" \
    'BEGIN { inserted = 0 }
     {
       print $0
       if (inserted == 0 && $0 ~ /^[[:space:]]*exec-once[[:space:]]*=[[:space:]]*bash[[:space:]]+~\/\.config\/artix-hypr-remix\/bin\/first-run\.sh([[:space:]]*(#.*)?)?$/) {
         print post_boot_line
         inserted = 1
       }
     }
     END {
       if (inserted == 0) {
         print post_boot_line
       }
     }' "$target_file"
}

if grep -Eq '^[[:space:]]*# Autostart[[:space:]]*$' "$target_file"; then
  insert_after_autostart_comment > "$temp_file"
elif [[ "$need_first_run" == "false" && "$need_post_boot" == "true" ]]; then
  insert_post_boot_after_first_run > "$temp_file"
elif grep -Eq '^[[:space:]]*exec-once[[:space:]]*=' "$target_file"; then
  insert_before_first_exec_once > "$temp_file"
else
  cat "$target_file" > "$temp_file"
  printf '\n# Autostart\n' >> "$temp_file"
  if [[ "$need_first_run" == "true" ]]; then
    printf '%s\n' "$first_run_line" >> "$temp_file"
  fi
  if [[ "$need_post_boot" == "true" ]]; then
    printf '%s\n' "$post_boot_line" >> "$temp_file"
  fi
fi

if cmp -s "$target_file" "$temp_file"; then
  echo "No autostart backfill changes needed"
  exit 0
fi

cp "$target_file" "$backup_file"
mv "$temp_file" "$target_file"

echo "Updated framework autostart hooks in $target_file"
echo "Backup written to $backup_file"
