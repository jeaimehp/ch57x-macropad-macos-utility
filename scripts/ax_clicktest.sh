#!/bin/bash
# Resize to min, dump, click first pad key, dump again.
cd ~/ch57xx-micropad
osascript -e 'tell application "System Events" to tell process "MicroPadStudio" to set size of window 1 to {980, 540}'
sleep 1
echo '=== BEFORE CLICK ==='
./scripts/ax_dump.sh
osascript <<'EOF'
tell application "System Events" to tell process "MicroPadStudio"
  set frontmost to true
  set everything to entire contents of window 1
  repeat with e in everything
    try
      if (class of e as string) is "button" then
        set bs to size of e
        set bp to position of e
        if (item 2 of bs) > 40 and (item 2 of bs) < 200 and (item 1 of bs) < 200 and (item 1 of bp) > 100 then
          click e
          return "clicked pad button at " & (item 1 of bp) & "," & (item 2 of bp)
        end if
      end if
    end try
  end repeat
  return "no button found"
end tell
EOF
sleep 1
echo '=== AFTER CLICK ==='
./scripts/ax_dump.sh
