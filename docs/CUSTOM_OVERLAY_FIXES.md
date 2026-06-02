# Custom Overlay Bug Fixes

Chatwoot's `custom/` overlay system is documented but has two bugs that prevent it from working.
These fixes are required when using the `custom/` directory approach.

## Bug 1: Custom directory not in autoload paths

**File:** `config/application.rb`

**Problem:** The `enterprise/app/**` directories are added to Rails eager_load_paths, but `custom/app/**` is not. Rails cannot autoload modules from `custom/`.

**Fix:** Add one line after the enterprise eager_load_paths:

```ruby
# rubocop:disable Rails/FilePath
config.eager_load_paths += Dir["#{Rails.root}/enterprise/app/**"]
config.eager_load_paths += Dir["#{Rails.root}/custom/app/**"] if Rails.root.join('custom').exist?
# rubocop:enable Rails/FilePath
```

**Merge conflict risk:** Low. Only triggers if upstream adds the same line.

---

## Bug 2: `const_get_maybe_false` crashes on `false` value

**File:** `config/initializers/01_inject_enterprise_edition_module.rb`

**Problem:** When `Object.const_defined?('Custom')` returns `false` (module not yet autoloaded), the `&&` operator short-circuits and returns `false` (not `nil`). Later, `false&.const_defined?(...)` calls `const_defined?` on `false` — Ruby's safe navigation `&.` only skips `nil`, not `false`. This causes:

```
NoMethodError: undefined method 'const_defined?' for false
```

**Fix:** Replace:

```ruby
def const_get_maybe_false(mod, name)
  mod&.const_defined?(name, false) && mod&.const_get(name, false)
end
```

With:

```ruby
def const_get_maybe_false(mod, name)
  return nil unless mod

  mod.const_defined?(name, false) && mod.const_get(name, false)
end
```

**Merge conflict risk:** Low. Only triggers if upstream fixes the same bug.

---

## After upstream merge

When pulling from upstream, if either file conflicts:

1. `config/application.rb` — keep the `custom/` line alongside whatever upstream changed
2. `01_inject_enterprise_edition_module.rb` — if upstream fixed the bug, drop your change; if not, reapply the `return nil unless mod` fix

Both are 1-line changes that are trivial to re-apply.
