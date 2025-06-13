
#!/bin/bash

ENC_DIR="/sys/class/enclosure/2:0:22:0"
COLS=4
ROWS=6
BOX_W=11

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
  # Populate slotmap with data for ALL physical slots (1-24)
  for i in $(seq 1 24); do
    IFS=";" read -r slot disk serial size <<<"$(get_slot_info $i)"
    slotmap[$i]="$slot;$disk;$serial;$size"
  done

  for row_idx in $(seq 0 $((ROWS-1))); do # Iterate through rows (0 to 5) for the visual grid
    # Print top of boxes for this row
    for col_idx in $(seq 0 $((COLS-1))); do # Iterate through columns (0 to 3) for the visual grid
      printf "+--------- "
    done
    printf "+\n"
    for line in 1 2 3 4; do
      for col_idx in $(seq 0 $((COLS-1))); do # Iterate through columns (0 to 3) for the visual grid
        # physical_slot determines which drive's data to retrieve.
        # This corresponds to the original left-to-right, top-to-bottom numbering.
        physical_slot=$(( row_idx * COLS + col_idx + 1 ))

        # display_slot determines the number shown as the label in the grid cell.
        # This follows top-down, then left-to-right column numbering.
        display_slot=$(( col_idx * ROWS + row_idx + 1 ))

        IFS=";" read -r slotn disk serial size <<<"${slotmap[$physical_slot]}"
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
          1) printf "|%-9s " "Slot $display_slot" ;; # Use the new display_slot for the label
          2) printf "|%-9s " "$disk_disp" ;;
          3) printf "|%-9s " "$serial_disp" ;;
          4) printf "|%5sTB " "$size_disp" ;; # Corrected padding here: %5sTB followed by one space
        esac
      done
      printf "|\n"
    done
    for col_idx in $(seq 0 $((COLS-1))); do # Iterate through columns (0 to 3) for the visual grid
      printf "+--------- "
    done
    printf "+\n"
  done
}

# Case-insensitive fuzzy serial lookup (last 4 chars)
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

# Case-insensitive label lookup
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
