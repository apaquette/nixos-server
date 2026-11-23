{ helpers, ... }:

let
  evaluate = helpers.evaluateTest;
  rejected = test: !(builtins.tryEval (evaluate "expected failure" test)).success;
in
[
  (helpers.assertEqual "boolean assertion count" 1 (evaluate "boolean assertion" true))
  (helpers.assertEqual "nested list assertion count" 3 (evaluate "nested assertions" [ true [ true true ] ]))
  (helpers.assertEqual "assertion record count" 1 (evaluate "assertion record" {
    assertion = true;
    message = "This assertion should pass.";
  }))
  (helpers.assertEqual "NixOS assertion group count" 2 (evaluate "NixOS assertion group" {
    assertions = [
      { assertion = true; message = "First assertion."; }
      { assertion = true; message = "Second assertion."; }
    ];
  }))
  (helpers.assertEqual "false boolean is rejected" true (rejected false))
  (helpers.assertEqual "false assertion record is rejected" true (rejected {
    assertion = false;
    message = "Expected failure.";
  }))
  (helpers.assertEqual "malformed assertion record is rejected" true (rejected { assertion = true; }))
  (helpers.assertEqual "non-boolean assertion is rejected" true (rejected {
    assertion = "true";
    message = "Assertion must be boolean.";
  }))
  (helpers.assertEqual "unsupported result is rejected" true (rejected 42))
  (helpers.assertEqual "non-list assertion group is rejected" true (rejected { assertions = true; }))
]
