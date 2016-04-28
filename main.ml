open Shorthands;;
open Formats;;

let slash = Filename.dir_sep;;
let out_dir = ("output");;

let formats = [
  Formats.zip_format;
  Formats.png_format;
  Formats.pdf_format;
  Formats.jpg_raw_format;
  Formats.jpg_jfif_format;
  Formats.jpg_exif_format;
  Formats.jpg_profile_format;
  Formats.gif_format ]
;;

let all_sig_start_hd = 
  (List.sort_uniq compare
    (List.map 
    (fun (f : Formats.file_format) -> (List.hd f.sig_start)) 
    formats))
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
;;

let buffer_of_indice i1 i2 =
  (seek i1);
  let buf = Buffer.create (i2-i1)
  in
  for i=i1 to i2 do
    Buffer.add_char buf (char_of_int (next ()))
  done; buf
;;

let perm = 0o777 in
let () = 
  try
    Unix.mkdir out_dir perm;
  with e -> ()
in
let () = 
  (List.iter 
    (fun f -> 
      (try 
        (Unix.mkdir (Printf.sprintf "%s%s%s" 
                out_dir slash f.filetype) perm)
      with e -> ())))
    formats
in

(* Keep reading until we are on top of a know file signature,
   returns (address_of_sig, format_of_sig) *)
let rec seek_until_sig_start () =
  let find_format_sig f = Formats.find_sig f.sig_start in
  let this_byte = (peek ()) in
  let byte_in_a_sig () = (List.mem this_byte all_sig_start_hd) in
  try
    if (byte_in_a_sig ()) then () else raise Not_found;
    let f = (List.find find_format_sig formats) in
    (where ()), f
  with Not_found -> (skip 1; seek_until_sig_start ()) 
in
try 
  while true do 
    (* Determine where the file starts, and its format *)
    let start,fmt = seek_until_sig_start ()
    in

    (* Determine where the file ends, sometimes 
       specific to the file type *)
    let eof = (fmt.find_eof_fn fmt) 
    in
    let r = fmt.num_found in
    let out_filename = Printf.sprintf "%d.%s" !r fmt.filetype in
    let out_path = 
      (Printf.sprintf "%s%s%s%s%s" 
       out_dir slash fmt.filetype slash out_filename) 
    in

    if eof != -1 then begin
      succ_ref (fmt.num_found);
      spit (buffer_of_indice start eof) out_path;
      Printf.printf "%-7s %+5d KB (0x%X - 0x%X)\n" 
        out_filename ((eof - start)/1024) start eof;
      seek eof;
      flush stdout;
    end else (seek (start + 1));

  done
with End_of_file -> print_endline "EOF"
