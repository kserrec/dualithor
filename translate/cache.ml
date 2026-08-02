(* On-disk cache for model replies.

   The project's standing constraint is that an identical LLM call is never paid
   for twice. The key is a digest of the *exact* request — model, system prompt,
   user message — so editing a few-shot example or switching model yields a
   different key and a fresh call. That is the behaviour we want: a cache hit
   has to mean "this exact question was asked before", never "something like it
   was". Being over-eager here would silently serve stale answers from an older
   prompt and quietly corrupt a measurement.

   Cached bodies live under data/cache/ and are gitignored: they are model
   output, not repo material. *)

let dir = Filename.concat "data" "cache"

(* A lookup key, not a security boundary — MD5 from the stdlib keeps this
   dependency-free. *)
let key ~model ~system ~user =
  Digest.to_hex (Digest.string (String.concat "\000" [ model; system; user ]))

let path k = Filename.concat dir (k ^ ".txt")

let find ~model ~system ~user : string option =
  match open_in_bin (path (key ~model ~system ~user)) with
  | exception Sys_error _ -> None
  | ic ->
      Fun.protect
        ~finally:(fun () -> close_in_noerr ic)
        (fun () -> Some (really_input_string ic (in_channel_length ic)))

let mkdir_quietly d =
  if not (Sys.file_exists d) then try Sys.mkdir d 0o755 with Sys_error _ -> ()

(* A cache write must never take down a run that already cost money: the reply
   is in hand either way, and a failed write only means paying again later. *)
let store ~model ~system ~user (body : string) : unit =
  mkdir_quietly "data";
  mkdir_quietly dir;
  match open_out_bin (path (key ~model ~system ~user)) with
  | exception Sys_error _ -> ()
  | oc ->
      Fun.protect
        ~finally:(fun () -> close_out_noerr oc)
        (fun () -> output_string oc body)
