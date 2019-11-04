# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: [rpc: 4, package: 1, service: 1],
  export: [
    locals_without_parens: [rpc: 4, package: 1, service: 1],
  ]
]
