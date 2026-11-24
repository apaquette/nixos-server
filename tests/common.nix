{ lib }:

let
  evaluateTest = name: test:
    if builtins.isBool test then
      if test then 1 else throw "Test '${name}' failed."
    else if builtins.isList test then
      lib.foldl' (count: nestedTest: count + evaluateTest name nestedTest) 0 test
    else if builtins.isAttrs test && test ? assertion && test ? message then
      if !builtins.isBool test.assertion then
        throw "Test '${name}' returned an assertion record with a non-boolean assertion."
      else if test.assertion then 1
      else throw "Test '${name}' failed: ${test.message}"
    else if builtins.isAttrs test && test ? assertions then
      if !builtins.isList test.assertions then
        throw "Test '${name}' returned an 'assertions' attribute that is not a list."
      else evaluateTest name test.assertions
    else if builtins.isAttrs test && (test ? assertion || test ? message) then
      throw "Test '${name}' returned a malformed assertion record; both 'assertion' and 'message' are required."
    else
      throw "Test '${name}' returned an unsupported result of type ${builtins.typeOf test}.";
in
{
  inherit evaluateTest;

  assertEqual = name: expected: actual:
    assert lib.assertMsg (expected == actual)
      "${name}: expected ${builtins.toJSON expected}, got ${builtins.toJSON actual}";
    true;

  assertContains = name: value: list:
    assert lib.assertMsg (builtins.elem value list)
      "${name}: expected list to contain ${builtins.toJSON value}";
    true;

  assertPathExists = name: path:
    assert lib.assertMsg (builtins.pathExists path)
      "${name}: expected path to exist: ${toString path}";
    true;
}
