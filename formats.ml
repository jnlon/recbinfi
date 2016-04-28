open Shorthands;;

let multi_max_file_size = (1024*768)*2;;
let simple_max_file_size = 1024*1024*10;;

type file_format = {
  filetype: string; 
  sig_start: int list; 
  sig_end: int list;
  max_size: int; 
  num_found: int ref;
  find_eof_fn: file_format -> int; }
;;

(* TODO: This really doesn't belong here *)
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

(* Stop when we find end of sig *)
let simple_find_eof (fmt: file_format) =  
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

(* ZIP files have a "central directory" near the end of the file. 
   20 bytes after the central dirctory is a two byte value indicating the
   length of the comment field, which is also how many bytes left to EOF *)
let zip_find_eof (fmt: file_format ) = 
  let started = (where ()) in
  let rec scan_for_eof () = 
    if (find_sig fmt.sig_end) then 
    begin
      (skip (20)); (*Skip to central directory*)
      let s1,s2 = (next ()),(next ()) in
      let comment_length = ((s1 lsl 8) lor s2) in
      (where ()) + (comment_length-1)
    end
    else if ((where ()) - started) < fmt.max_size then -1
    else (skip 1; scan_for_eof ())
  in
  (scan_for_eof ())
;;

(* Some PDFs end in \r\n, instead of just \n *)
let pdf_find_eof (fmt: file_format) = 
  let started = (where ()) in
  let rec scan_for_eof last_found_eof = 
    try
      let found_sig = 
        List.find 
        find_sig 
        [(fmt.sig_end @ [0x0D;0x0A]); (fmt.sig_end @ [0x0A])]
      in
      let new_eof = ((where ()) + (List.length found_sig) - 1)
      in
      (skip 1);
      scan_for_eof new_eof
    with Not_found -> begin
      if ((where ()) - started) < fmt.max_size 
      then ((skip 1); (scan_for_eof last_found_eof))
      else last_found_eof
    end
  in
  (scan_for_eof (-1))
;;


(* The EOF of some filetypes (such as GIF) is ambiguous, since the EOF
   signature may occur several times in the same file. So, we keep looking for
   the EOF sig even after finding one, and we only stop once we pass max_size *)
let rec multi_find_eof (fmt: file_format) =

  let start = (where()) 
  in
  let havent_gone_too_far () = 
    ((where ()) - start) < fmt.max_size
  in

  let rec scan_for_eof last_eof_location = 

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
  max_size = 1024*1024*15;
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
