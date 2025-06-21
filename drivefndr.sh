#!/bin/bash

# === CONFIG SECTION ===

ENC_DIR="/sys/class/enclosure/2:0:22:0"
COLS=4
ROWS=6

# --- Optional custom display labels ---
USE_CUSTOM_LABELS=0
DISPLAY_LABELS_GRID="
  Slot\ 1  Slot\ 2  Slot\ 3  Slot\ 4
  Slot\ 5  Slot\ 6  Slot\ 7  Slot\ 8
  Slot\ 9  Slot\ 10 Slot\ 11 Slot\ 12
  Slot\ 13 Slot\ 14 Slot\ 15 Slot\ 16
  Slot\ 17 Slot\ 18 Slot\ 19 Slot\ 20
  Slot\ 21 Slot\ 22 Slot\ 23 Slot\ 24
"


# Set USE_CUSTOM_LABELS=0 to use default "Slot X" labels.

# === END CONFIG ===

parse_slot_grid() {
  SLOT_MAP=()
  local idx=1
  for ((row=0; row<ROWS; row++)); do
    for ((col=0; col<COLS; col++)); do
      SLOT_MAP+=( "$idx" )
      idx=$((idx+1))
    done
  done
}

parse_display_labels_grid() {
  DISPLAY_LABELS=()
  if [[ "$USE_CUSTOM_LABELS" == "1" && -n "$DISPLAY_LABELS_GRID" ]]; then
    while read -r line; do
      [[ -z "$line" ]] && continue
      for label in $line; do
        DISPLAY_LABELS+=( "$label" )
      done
    done <<< "$DISPLAY_LABELS_GRID"
  fi
}

get_slot_info() {
  slot=$1
  slotdir=$(printf "%s/Disk%03d" "$ENC_DIR" "$slot")
  disk=$(ls "$slotdir/device/block" 2>/dev/null)
  if [ -n "$disk" ]; then
    serial=$(smartctl -i "/dev/$disk" | awk -F: '/Serial Number/{print $2}' | xargs)
    size=$(lsblk -b -dn -o SIZE "/dev/$disk" 2>/dev/null)
    [ -n "$size" ] && size=$(awk "BEGIN {printf \"%.0f\", $size/1024/1024/1024/1024}")
    [ -z "$size" ] && size="?"
    printf "%s;%s;%s;%s" "$slot" "$disk" "${serial:0:8}" "$size"
  else
    printf "%s;EMPTY;-;-"
  fi
}

print_grid() {
  declare -A slotmap
  parse_slot_grid
  parse_display_labels_grid
  total_slots=$((ROWS*COLS))
  for i in $(seq 0 $((total_slots-1))); do
    slotid="${SLOT_MAP[$i]}"
    if [[ "$slotid" == "skip" || -z "$slotid" ]]; then
      slotmap[$i]="-;EMPTY;-;-"
    else
      IFS=";" read -r slot disk serial size <<<"$(get_slot_info $slotid)"
      slotmap[$i]="$slot;$disk;$serial;$size"
    fi
  done

  for row_idx in $(seq 0 $((ROWS-1))); do
    for col_idx in $(seq 0 $((COLS-1))); do printf "+--------- "; done
    printf "+\n"
    for line in 1 2 3 4; do
      for col_idx in $(seq 0 $((COLS-1))); do
        idx=$((row_idx * COLS + col_idx))
        IFS=";" read -r slotn disk serial size <<<"${slotmap[$idx]}"
        if [[ "$USE_CUSTOM_LABELS" == "1" && -n "${DISPLAY_LABELS[$idx]}" ]]; then
          label="${DISPLAY_LABELS[$idx]}"
        else
          label="Slot $((col_idx * ROWS + row_idx + 1))"
        fi
        if [ "$disk" = "EMPTY" ]; then
          disk_disp="EMPTY"
          serial_disp="-"
          size_disp="-"
        else
          disk_disp="$disk"
          serial_disp="$serial"
          size_disp="$size"
        fi
        case $line in
          1) printf "|%-9s " "$label" ;;
          2) printf "|%-9s " "$disk_disp" ;;
          3) printf "|%-9s " "$serial_disp" ;;
          4) printf "|%5sTB " "$size_disp" ;;
        esac
      done
      printf "|\n"
    done
    for col_idx in $(seq 0 $((COLS-1))); do printf "+--------- "; done
    printf "+\n"
  done
}

lookup_serial() {
  read -p "Enter last 4 of serial number: " q
  q=$(echo "$q" | tr '[:lower:]' '[:upper:]' | xargs)
  found=0
  for i in $(seq 1 24); do
    disk=$(ls "$ENC_DIR/Disk$(printf "%03d" $i)/device/block" 2>/dev/null)
    [ -z "$disk" ] && continue
    serial=$(smartctl -i "/dev/$disk" 2>/dev/null | awk -F: '/Serial Number/{print $2}' | xargs)
    serialu=$(echo "$serial" | tr '[:lower:]' '[:upper:]')
    if [[ "$serialu" == *"$q" ]]; then
      echo "Slot $i: $disk  Serial: $serial"
      found=1
    fi
  done
  [ "$found" -eq 0 ] && echo "No serial found matching '$q'"
}

lookup_label() {
  read -p "Enter device label (e.g., sdo): " q
  q=$(echo "$q" | xargs)
  for i in $(seq 1 24); do
    disk=$(ls "$ENC_DIR/Disk$(printf "%03d" $i)/device/block" 2>/dev/null)
    if [[ "$disk" == "$q" ]]; then
      serial=$(smartctl -i "/dev/$disk" 2>/dev/null | awk -F: '/Serial Number/{print $2}' | xargs)
      echo "Slot $i: $disk Serial: $serial"
      return
    fi
  done
  echo "Device label not found."
}

while true; do
  echo
  echo "1) Lookup by Serial (last 4 chars, case-insensitive)"
  echo "2) Lookup by Label"
  echo "3) Show Slot Map (Grid)"
  echo "q) Quit"
  read -p "> " opt
  case $opt in
    1) lookup_serial ;;
    2) lookup_label ;;
    3) print_grid ;;
    q|Q) break ;;
    *) echo "Invalid option." ;;
  esac
done
