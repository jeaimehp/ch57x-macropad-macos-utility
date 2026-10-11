#!/bin/bash
# Dump window + content-button geometry of MicroPadStudio (skill recipe)
osascript <<'EOF'
tell application "System Events" to tell process "MicroPadStudio"
  set p to position of window 1
  set s to size of window 1
  set everything to entire contents of window 1
  set o to "WINDOW x=" & (item 1 of p) & " y=" & (item 2 of p) & " w=" & (item 1 of s) & " h=" & (item 2 of s) & linefeed
  repeat with e in everything
    try
      if (class of e as string) is "button" then
        set bp to position of e
        set bs to size of e
        if (item 2 of bs) > 40 and (item 1 of bs) < 200 then
          set o to o & "BTN x=" & (item 1 of bp) & " y=" & (item 2 of bp) & " w=" & (item 1 of bs) & " h=" & (item 2 of bs) & linefeed
        end if
      end if
    end try
  end repeat
  return o
end tell
EOF
