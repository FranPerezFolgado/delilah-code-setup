# Merge a file rulesync generated into the user's copy of it.
# Usage: jq --indent 2 --slurpfile tpl GENERATED -f merge-json.jq USER
# Objects merge key by key, arrays are an ordered union (user's entries first,
# then generated ones they lack), and on any other clash the user's value wins.
def dm($u; $g):
  if ($u | type) == "object" and ($g | type) == "object" then
    reduce ($g | keys_unsorted[]) as $k ($u;
      .[$k] = (if has($k) then dm(.[$k]; $g[$k]) else $g[$k] end))
  elif ($u | type) == "array" and ($g | type) == "array" then
    $u + ($g - $u)
  else $u end;
dm(.; $tpl[0])
