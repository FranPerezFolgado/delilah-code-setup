# Replace the hook set rulesync owns in ~/.gemini/config/hooks.json ("rulesync")
# and keep every other hook set as it is.
# Usage: jq --indent 2 --slurpfile tpl GENERATED -f merge-hookset.jq USER
if ($tpl[0] | has("rulesync")) then .rulesync = $tpl[0].rulesync
else error("generated hooks.json has no \"rulesync\" hook set") end
