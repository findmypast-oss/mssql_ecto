ecto = Mix.Project.deps_paths()[:ecto]
ecto = "#{ecto}/integration_test/cases"

"""

# Partial Support

> Code.require_file("assoc.exs", ecto)
Most tests pass.

* Throws "No SQL-driver information available." error instead of expected errors.
* Unique contraint
* cascading delete doesn't work
* many-to-many doesn't return duplicates

> Code.require_file("joins.exs", ecto)
2 tests fail.

* Incorrect syntax near the keyword 'ON'
* Unique constraint


> Code.require_file("preload.exs", ecto)
most tests pass. Needs investigation

* Unique constraint
* Incorrect syntax 'COUNT'
* Incorrect preload behaviour

> Code.require_file("repo.exs", ecto)
most tests pass. Needs investigation

# Needs investigation

> Code.require_file("type.exs", ecto)
> Code.require_file("windows.exs", ecto)


# Not Implemented
> Code.require_file("interval.exs", ecto)
The complex date time stuff is not implemented

"""
