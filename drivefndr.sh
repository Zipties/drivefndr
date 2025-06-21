#!/bin/bash
##############################################################################
#                              USER CONFIG SECTION                           #
##############################################################################

# Number of columns (horizontal slots per row)
COLS=4
# Number of rows (vertical)
ROWS=6
# Do you want to use custom labels in the grid? (1 = yes, 0 = auto-number)
USE_CUSTOM_LABELS=0
# Define the labels for each slot, row by row (use single quotes for multi-word labels)
# If USE_CUSTOM_LABELS=0, this section is ignored.
DISPLAY_LABELS_GRID="
  'Slot 1'  'Slot 2'  'Slot 3'  'Slot 4'
  'Slot 5'  'Slot 6'  'Slot 7'  'Slot 8'
  'Slot 9'  'Slot 10' 'Slot 11' 'Slot 12'
  'Slot 13' 'Slot 14' 'Slot 15' 'Slot 16'
  'Slot 17' 'Slot 18' 'Slot 19' 'Slot 20'
  'Slot 21' 'Slot 22' 'Slot 23' 'Slot 24'
"

##############################################################################
#                         END USER CONFIG SECTION                            #
##############################################################################

# --- Enclosure detection and persistent config ---
CONFIG_FILE="$HOME/.slotgrid.conf"

select_enclosure() {
  mapfile -t ENCLOSURES < <(find /sys/class/enclosure -maxdepth 1 -mindepth 1 \( -type d -o -type l \) | sort)
  if [ ${#ENCLOSURES[@]} -eq 0 ]; then
    echo "No enclosures found under /sys/class/enclosure."
    exit 1
  fi

  echo "Available enclosures:"
  for i in "${!ENCLOSURES[@]}"; do
    echo " $((i+1))) ${ENCLOSURES[$i]}"
  done
  while true; do
    read -p "Select enclosure number [1-${#ENCLOSURES[@]}]: " selection
    if [[ "$selection" =~ ^[1-9][0-9]*$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#ENCLOSURES[@]} ]; then
      echo "ENC_DIR=\"${ENCLOSURES[$((selection-1))]}\"" > "$CONFIG_FILE"
      break
    else
      echo "Invalid selection."
    fi
  done
}

# --- Always load ENC_DIR from config or ask user on first run ---
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
else
  select_enclosure
  source "$CONFIG_FILE"
fi

# --- Core functions ---

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
      eval "set -- $line"
      for label; do
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
  for i in $(seq 1 $((COLS*ROWS))); do
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
  for i in $(seq 1 $((COLS*ROWS))); do
    disk=$(ls "$ENC_DIR/Disk$(printf "%03d" $i)/device/block" 2>/dev/null)
    if [[ "$disk" == "$q" ]]; then
      serial=$(smartctl -i "/dev/$disk" 2>/dev/null | awk -F: '/Serial Number/{print $2}' | xargs)
      echo "Slot $i: $disk Serial: $serial"
      return
    fi
  done
  echo "Device label not found."
}

# --- Main menu loop ---

while true; do
  echo
  echo "1) Lookup by Serial (last 4 chars, case-insensitive)"
  echo "2) Lookup by Label"
  echo "3) Show Slot Map (Grid)"
  echo "4) Change Enclosure"
  echo "q) Quit"
  read -p "> " opt
  case $opt in
    1) lookup_serial ;;
    2) lookup_label ;;
    3) print_grid ;;
    4) select_enclosure; source "$CONFIG_FILE" ;;
    q|Q) break ;;
    *) echo "Invalid option." ;;
  esac
done
