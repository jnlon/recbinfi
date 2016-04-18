_:
	ocamlopt unix.cmxa main.ml -o recbinfi
clean: 
	rm main.cmi main.cmx main.o recbinfi
