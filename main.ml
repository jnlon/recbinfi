let out_dir = ("output");;
let in_chan = open_in_bin Sys.argv.(1);;
let slash = Filename.dir_sep;;
let safe_max_file_size = 1024*1024*10;;
let next () = input_byte in_chan;;
let where () = pos_in in_chan;;
let soi s = string_of_int s;;
let print_int_sp i = print_int i; print_char ' ';;
let print_int_endl i = print_int i; print_newline ();;
let fail msg = print_endline msg; exit 1;;
let rewind time = seek_in in_chan time;;
let skip n = seek_in in_chan ((where ()) + n);;
let is_true p = (p = true);;

let find_sig f_sig =
  let rec follow_sig sig_lst = 
    let next_b = (next ()) 
    in
    match sig_lst with
      | [last] when last = next_b -> true
      | (hd :: tl) when hd = next_b -> follow_sig tl 
      | _ -> false
  in
  let start = (where ()) in
  let result = follow_sig f_sig in
  rewind start;
  result
;;

type file_format = {
  filetype: string; 
  sig_start: int list; 
  sig_end: int list;
  max_size: int; 
  num_found: int ref;
  find_eof_fn: file_format -> int; }
;;

let simple_find_eof (fmt: file_format) =  (*Stop when we find end of sig*)
  let rec loop times =
    if (find_sig fmt.sig_end)
    then ((where ()) + (List.length fmt.sig_end) - 1)
    else begin
      if times > fmt.max_size
      then -1
      else (skip 1; loop (times+1))
    end
  in loop 0
;;

(* The EOF of a gif is ambiguous, since its EOF is also the end of a gif frame. 
 * So, we keep looking for the EOF sig even after finding one, and we only
 * stop once we pass max_size in the current frame*)
let rec gif_find_eof (fmt: file_format) =

  let start = (where ()) in

  let rec scan_for_eof last_eof_location = 

    (*Printf.printf "last_eof: %d\n" last_eof_location;
    flush stdout;*)

    let start_frame = (where()) 
    in
    let within_gif_bounds () = 
      ((where ()) - start_frame) < fmt.max_size
    in
    while (within_gif_bounds ()) && (not (find_sig fmt.sig_end))
    do (skip 1)
    done;

    if (within_gif_bounds ()) then begin
      let eof_location = ((where ()) + (List.length fmt.sig_end) - 1) in
      (skip 1);
      try
        scan_for_eof eof_location
      with End_of_file -> eof_location
    end
    else last_eof_location
  in
  scan_for_eof (-1);
;;

let png_format = {
  filetype = "png";
  sig_start = [137;80;78;71;13;10;26;10];
  sig_end = [73;69;78;68;174;66;96;130];
  max_size = safe_max_file_size;
  num_found = ref 0;
  find_eof_fn = simple_find_eof }
;;

let jpg_format = {
  filetype = "jpg";
  sig_start = [255;216;255];
  sig_end = [255;217];
  max_size = safe_max_file_size;
  num_found = ref 0; 
  find_eof_fn = simple_find_eof }
;;

let gif_format = {
  filetype = "gif";
  sig_start = [71;73;70;56;57;97];
  sig_end = [0;59];
  max_size = 1024*512;
  num_found = ref 0; 
  find_eof_fn = gif_find_eof }
;;

let formats = [
  png_format;
  jpg_format;
  gif_format ]
;;

let succ_ref r = 
  r := (!r + 1)
;;

let bytes_of_int_list lst =
  let bytes = Bytes.create (List.length lst) in
  for i=0 to ((List.length lst)-1) do
    Bytes.set bytes i (char_of_int (List.nth lst i))
  done; bytes
;;

let spit buf filename = 
  let out_chan = open_out filename 
  in
  Buffer.output_buffer out_chan buf;
  close_out out_chan;
  (*Printf.printf "Spat buf to %s (size %d)\n" 
     filename (Buffer.length buf);*)
;;

let buffer_of_indice i1 i2 =
  (rewind i1);
  let buf = Buffer.create (i2-i1)
  in
  for i=i1 to i2 do
    Buffer.add_char buf (char_of_int (next ()))
  done; buf
;;

let () = begin  (* Make directories *)
  let perm = 0o700 in
  try
    Unix.mkdir out_dir perm;
    List.iter 
      (fun f -> 
        Unix.mkdir (Printf.sprintf "%s%s%s" 
                  out_dir slash f.filetype) perm)
      formats
  with e -> ()
end;

try 
  while true do 
    (*Determine where the file starts, and its format *)
    let start,fmt = 
      let rec loop () =
        try
          let f = (List.find (fun f -> find_sig f.sig_start) formats) in
          (where ()), f
        with Not_found -> (skip 1; loop ())
      in loop ()
    in

    Printf.printf "Found start: %d\n" start;

    (*Determine where the file ends, 
     *sometimes specific to each file type*)
    let eof = (fmt.find_eof_fn fmt) 
    in

    let r = fmt.num_found in
    let out_filename = 
      (Printf.sprintf "%s%s%s%s%d.%s" 
       out_dir slash fmt.filetype slash !r fmt.filetype) 
    in

    if eof != -1 then begin
      succ_ref (fmt.num_found);
      spit (buffer_of_indice start eof) out_filename;
      Printf.printf "'%d.%s' saved (%d - %d = %d bytes) \n" 
        !r fmt.filetype eof start (eof - start);
      rewind eof;
      flush stdout;
    end else (rewind (start + 1));

  done
with End_of_file -> print_endline "EOF"
