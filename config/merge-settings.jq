# Merge the settings.json rulesync generated into an existing one.
# Usage: jq --indent 2 --slurpfile tpl GENERATED -f merge-settings.jq USER
# Contract: specs/001-engram-session-memory/contracts/settings-merge.md
. as $u
| $tpl[0] as $t
# ordered union: U + (T - U)
| def union($a; $b): ($a // []) as $x | $x + (($b // []) - $x);
  # deep merge, user wins on leaves
  ($t * $u)
  | .autoMemoryEnabled = false
  | reduce ("allow", "deny", "ask") as $k (.;
      if ($u.permissions[$k] // $t.permissions[$k]) == null then .
      else .permissions[$k] = (union($u.permissions[$k]; $t.permissions[$k])
        # Older installs used the "Bash(cmd:*)" form; drop it when the template
        # has the same rule as "Bash(cmd *)", which Claude Code reads the same way.
        | ($t.permissions[$k] // []) as $tk
        | map(select(. as $e | ($e | test("^Bash\\(.*:\\*\\)$"))
            and ($tk | index($e | sub(":\\*\\)$"; " *)")) != null) | not)))
      end)
  | reduce (($t.hooks // {}) | keys[]) as $ev (.;
      ([($u.hooks[$ev] // [])[].hooks[]?.command]) as $have
      | .hooks[$ev] = (($u.hooks[$ev] // []) + [
          $t.hooks[$ev][]
          | select([.hooks[]?.command] | all(. as $c | ($have | index($c)) == null))
        ]))
  | if ($u.mcpServers // $t.mcpServers) == null then .
    else .mcpServers = (($t.mcpServers // {}) + ($u.mcpServers // {})) end
