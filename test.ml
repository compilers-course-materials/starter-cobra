open Compile
open Runner
open Printf
open OUnit2

let t name program expected = name>::test_run program name expected;;
let te name program expected = name>::test_err program name expected;;

let forty = "let x = 40 in x"
let fals = "let x = false in x"
let tru = "let x = true in x"

let suite =
"suite">:::
 [
  t "forty" forty "40";
  t "fals" fals "false";
  t "tru" tru "true";
 
 
 ]
;;


let () =
  run_test_tt_main suite
;;
