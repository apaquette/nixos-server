{ helpers, ... }:

# This assertion deliberately fails until the test evaluator is implemented.
# It establishes the missing behaviour before the production harness changes.
assert helpers.evaluateTest "passing boolean assertion" true == 1;

[
  (helpers.assertEqual
    "passing boolean assertion is counted"
    1
    (helpers.evaluateTest "passing boolean assertion" true))
]
