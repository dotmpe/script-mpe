Debug links for sitefile.

- [info](/Sitefile/info)
- [resource debug](/Sitefile/debug/resource)
- [pug opts debug](/Sitefile/debug/resource/pug-opts)
- [global debug](/Sitefile/debug/global) or [core]
- [yaml asis](/Sitefile.yaml)
- [resolve all to json](/Sitefile.json)
- [autocomplete url](/Sitefile/core/auto)

Routes:
```YAML

  Sitefile/core: core:#
  Sitefile.yaml: static:Sitefile.yaml
  Sitefile.json: sitefile:?resolve=sitefile
  Sitefile/debug/resource: sitefile.rctx:#
  Sitefile/debug/resource/opts: sitefile.rctx-opts:#
  Sitefile/info: sitefile.info:#

  Sitefile/debug/global: redir:Sitefile/core
  Sitefile/json: redir:Sitefile.json
  Sitefile/debug: redir:Sitefile/debug/resource

  Sitefile/core/auto: core.autocomplete:#

  _markdown: markdown-it:*.md
  _markdown_1: markdown-it:example/**/*.md
```
