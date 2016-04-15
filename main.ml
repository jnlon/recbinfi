let multi_max_file_size = (1024*768)*2;;
let simple_max_file_size = 1024*1024*10;;
let slash = Filename.dir_sep;;
let out_dir = ("output");;

let in_chan = open_in_bin Sys.argv.(1);;
let seek time = seek_in in_chan time;;
let next () = input_byte in_chan;;
let where () = pos_in in_chan;;
let rewind place = seek ((where ()) - place);;
let peek () = let b = (input_byte in_chan) in (rewind 1); b;;
let soi s = string_of_int s;;
let print_int_sp i = print_int i; print_char ' ';;
let print_int_endl i = print_int i; print_newline ();;
let fail msg = print_endline msg; exit 1;;
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
  seek start;
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

(*ZIP files have a "central directory" near the end of the file. 
  20 bytes after the central dirctory is a two byte value indicating the length
  of the comment field, which is also how many bytes left to EOF *)
let zip_find_eof (fmt: file_format ) = 
  let rec scan_for_eof () = 
    if (find_sig fmt.sig_end) then 
    begin
      (skip (20)); (*Skip to central directory*)
      let s1,s2 = (next ()),(next ()) in
      let comment_length = ((s1 lsl 8) lor s2) in
      (where ()) + (comment_length-1)
    end
    else (skip 1; scan_for_eof ())
  in
  (scan_for_eof ())
;;

(*NOTE: Some PDFs end in \r\n, instead of just \n *)
let pdf_find_eof (fmt: file_format ) = 
  let rec scan_for_eof () = 
    try
      let found_sig = 
        List.find 
        find_sig 
        [(fmt.sig_end @ [0x0D;0x0A]); (fmt.sig_end @ [0x0A])]
      in
      ((where ()) + (List.length found_sig) - 1)
    with Not_found -> ((skip 1); (scan_for_eof ()))
  in
  (scan_for_eof ())
;;


(* The EOF of some filetypes (such as GIF) is ambiguous, since the EOF
 * signature may occur several times in the same file. So, we keep looking for
 * the EOF sig even after finding one, and we only stop once we pass max_size*)
let rec multi_find_eof (fmt: file_format) =

  let rec scan_for_eof last_eof_location = 

    (*Printf.printf "last_eof: %d\n" last_eof_location;
    flush stdout;*)

    let start_frame = (where()) 
    in
    let havent_gone_too_far () = 
      ((where ()) - start_frame) < fmt.max_size
    in
    while (havent_gone_too_far ()) && (not (find_sig fmt.sig_end))
    do (skip 1)
    done;

    if (havent_gone_too_far ()) then begin
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
  sig_start = [0x89;0x50;0x4E;0x47;0xD;0xA;0x1A;0xA];
  sig_end = [0x49;0x45;0x4E;0x44;0xAE;0x42;0x60;0x82];
  max_size = simple_max_file_size;
  num_found = ref 0;
  find_eof_fn = simple_find_eof }
;;

let zip_format = {
  filetype = "zip";
  sig_start = [0x50; 0x4B; 0x03; 0x04];
  sig_end = [0x50; 0x4B; 0x05; 0x06]; (*Central directory signature*)
  max_size = simple_max_file_size;
  num_found = ref 0;
  find_eof_fn = zip_find_eof }
;;

let pdf_format = {
  filetype = "pdf";
  sig_start = [0x25;0x50;0x44;0x46];
  sig_end = [0x25;0x45;0x4F;0x46]; (* @ [0x0A] | [0x0D;0x0A] *)
  max_size = simple_max_file_size;
  num_found = ref 0;
  find_eof_fn = pdf_find_eof }
;;

let jpg_raw_format = {
  filetype = "jpg";
  sig_start = [0xFF; 0xD8; 0xFF; 0xDB];
  sig_end = [0xFF;0xD9];
  max_size = multi_max_file_size;
  num_found = ref 0; 
  find_eof_fn = multi_find_eof }
;;

let jpg_profile_format = {
  filetype = "jpg";
  sig_start = [0xFF; 0xD8; 0xFF; 0xE2; 0x0C];
  sig_end = [0xFF;0xD9];
  max_size = multi_max_file_size;
  num_found = jpg_raw_format.num_found;
  find_eof_fn = multi_find_eof }
;;

let jpg_exif_format = {
  filetype = "jpg";
  sig_start = [0xFF;0xD8;0xFF;0xE1];
  sig_end = [0xFF;0xD9];
  max_size = multi_max_file_size;
  num_found = jpg_raw_format.num_found;
  find_eof_fn = multi_find_eof}
;;

let jpg_jfif_format = {
  filetype = "jpg";
  sig_start = [0xFF;0xD8;0xFF;0xE0;0x00;
               0x10;0x4A;0x46;0x49;0x46];
  sig_end = [0xFF;0xD9];
  max_size = multi_max_file_size;
  num_found = jpg_raw_format.num_found;
  find_eof_fn = multi_find_eof}
;;

let gif_format = {
  filetype = "gif";
  sig_start = [0x47;0x49;0x46;0x38;0x39;0x61];
  sig_end = [0x00;0x3B];
  max_size = multi_max_file_size;
  num_found = ref 0; 
  find_eof_fn = multi_find_eof}
;;

let formats = [
  zip_format;
  png_format;
  pdf_format;
  jpg_raw_format;
  jpg_jfif_format;
  jpg_exif_format;
  jpg_profile_format;
  gif_format ]
;;

let all_sig_start_hd = 
  (List.sort_uniq compare
    (List.map 
    (fun f -> (List.hd f.sig_start)) 
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

try 
  while true do 
    (*Determine where the file starts, and its format *)
    let start,fmt = 
      let find_format_sig f = find_sig f.sig_start in
      let rec loop () =
        let this_byte = (peek ()) in
        let byte_in_a_sig () = (List.mem this_byte all_sig_start_hd) in
        try
          if (byte_in_a_sig ()) then () else raise Not_found;
          let f = (List.find find_format_sig formats) in
          (where ()), f
        with Not_found -> (skip 1; loop ())
      in loop ()
    in

    (*print_endline "Looking for eof now...";
    print_endline fmt.filetype;*)

    (*Determine where the file ends, sometimes 
     * specific to the file type (eg, GIF) *)
    let eof = (fmt.find_eof_fn fmt) in
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
