_mix_deps:
  out=$(mix deps.get) && echo "all dependencies fetched" || { echo "$out"; exit 1; }

test:
  mix test

lint:
  mix compile --force --warnings-as-errors
  mix credo

dialyzer:
  mix dialyzer

format:
  mix format --migrate

_libdev_check:
  mix libdev.check

_git_status:
  git status

docs:
  mix docs

changelog:
  git cliff -o CHANGELOG.md

check: _mix_deps format _libdev_check _git_status

