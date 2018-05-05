setup()
{
  verbosity=0
  load init
}

@test "doc, docs, find-doc and find-docs have online help" {

  run htd help doc
  test_ok_nonempty "*htd doc*" || stdfail help-doc
  run htd help docs
  test_ok_nonempty "*htd docs*" || stdfail help-docs
  run htd help find-doc
  test_ok_nonempty || stdfail find-doc-help
  run htd help find-docs
  test_ok_nonempty || stdfail find-docs-help
}

@test "script.mpe#test holds custom orderer" {
  TODO
}

@test "htd find-docs returns output from package-docs-find handler" {

  _Test() {
    package_docs_find=echo htd find-docs "$@"
  }
  run _Test foo
  test_ok_nonempty "*foo"
}

@test "htd find-doc returns output from package-doc-find handler" {

  _Test() {
    package_doc_find=echo htd find-doc "$@"
  }
  run _Test foo2
  test_ok_lines "foo2"
}
