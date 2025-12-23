#######################################
# 3️⃣ Interactive cron setup
#######################################

# Read existing cron entries for this script
EXISTING_LINES=$(crontab -l 2>/dev/null | grep -F "$SHUTDOWN_SCRIPT" || true)

EXISTING_TIMES=()
if [ -n "$EXISTING_LINES" ]; then
  while read -r MIN HOUR _; do
    EXISTING_TIMES+=("$(printf "%02d:%02d" "$HOUR" "$MIN")")
  done <<< "$(echo "$EXISTING_LINES" | awk '{print $1, $2}')"
fi

MODE="add"
if [ "${#EXISTING_TIMES[@]}" -gt 0 ]; then
  echo
  echo "Existing shutdown timers detected:"
  for T in "${EXISTING_TIMES[@]}"; do
    echo "  - $T"
  done
  echo
  while true; do
    echo "What would you like to do?"
    echo "1) Add additional timers"
    echo "2) Replace all existing timers"
    read -rp "Choice (1/2): " CHOICE
    case "$CHOICE" in
      1) MODE="add"; break ;;
      2) MODE="replace"; break ;;
      *) echo "Please choose 1 or 2." ;;
    esac
  done
fi

if [ "$MODE" = "replace" ]; then
  BASE_COUNT=0
else
  BASE_COUNT="${#EXISTING_TIMES[@]}"
fi

MAX_NEW=$((5 - BASE_COUNT))
if [ "$MAX_NEW" -le 0 ]; then
  echo "You already have 5 shutdown timers. Cannot add more."
  exit 0
fi

echo
while true; do
  read -rp "How many new shutdown timers do you want to add? (1–$MAX_NEW): " COUNT
  [[ "$COUNT" =~ ^[1-5]$ ]] && [ "$COUNT" -le "$MAX_NEW" ] && break
  echo "Please enter a number between 1 and $MAX_NEW."
done

NEW_TIMES=()
for ((i=1; i<=COUNT; i++)); do
  while true; do
    read -rp "Enter time #$i (HH:MM, 24h): " TIME
    if [[ "$TIME" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
      NEW_TIMES+=("$TIME")
      break
    else
      echo "Invalid time format. Example: 18:00"
    fi
  done
done

# Build new cron
CURRENT_CRON="$(crontab -l 2>/dev/null || true)"

if [ "$MODE" = "replace" ]; then
  # Remove existing shutdown timers
  CURRENT_CRON="$(echo "$CURRENT_CRON" | grep -vF "$SHUTDOWN_SCRIPT" || true)"
fi

for T in "${NEW_TIMES[@]}"; do
  HOUR="${T%:*}"
  MIN="${T#*:}"
  LINE="$MIN $HOUR * * * $SHUTDOWN_SCRIPT"
  echo "$CURRENT_CRON" | grep -Fq "$LINE" || CURRENT_CRON+=$'\n'"$LINE"
done

echo "$CURRENT_CRON" | crontab -

#######################################
# Summary
#######################################
echo
echo "==> Shutdown timers now configured:"
(crontab -l | grep -F "$SHUTDOWN_SCRIPT" | awk '{printf "  - %02d:%02d\n", $2, $1}')
