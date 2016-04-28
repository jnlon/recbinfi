val multi_max_file_size : int
val simple_max_file_size : int
type file_format = {
  filetype : string;
  sig_start : int list;
  sig_end : int list;
  max_size : int;
  num_found : int ref;
  find_eof_fn : file_format -> int;
}
val find_sig : int list -> bool
val simple_find_eof : file_format -> int
val zip_find_eof : file_format -> int
val pdf_find_eof : file_format -> int
val multi_find_eof : file_format -> int
val png_format : file_format
val zip_format : file_format
val pdf_format : file_format
val jpg_raw_format : file_format
val jpg_profile_format : file_format
val jpg_exif_format : file_format
val jpg_jfif_format : file_format
val gif_format : file_format
